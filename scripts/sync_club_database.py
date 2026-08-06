#!/usr/bin/env python3
"""
Sync ClubDatabase.json against the weekly Transfermarkt datasets dump
(https://github.com/dcaribou/transfermarkt-datasets).

Why not transfermarkt-api.fly.dev?
  That API scrapes transfermarkt.com live; when TM's CDN has no DNS A/AAAA
  records the API returns 500s. The DuckDB dump is the reliable weekly snapshot
  and uses the same player/club IDs we already store.

What it does:
  • Refresh every tracked club's squad (last_season = current)
  • Update name / position / nationality / market value when changed
  • Add new players who joined one of our clubs (+ download portrait)
  • Move players with no current club / stale season → Free Agent club
  • Drop players who transferred to a club we don't track

Usage:
  python3 scripts/sync_club_database.py
  python3 scripts/sync_club_database.py --skip-portraits
  python3 scripts/sync_club_database.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = ROOT / "test" / "Database" / "ClubDatabase.json"
PORTRAIT_DIR = ROOT / "test" / "Database" / "PlayerPortraits"
SYNC_DIR = ROOT / "build" / "sync"
DUCKDB_PATH = SYNC_DIR / "transfermarkt-datasets.duckdb"
REPORT_PATH = SYNC_DIR / "sync_report.json"
DUCKDB_URL = "https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data/transfermarkt-datasets.duckdb"

FREE_AGENT_ID = "free-agent"
FREE_AGENT_NAME = "Free Agent"
PORTRAIT_SIZE = 128
HEADERS = {"User-Agent": "FootballQuizApp/1.0 (data-sync)"}
MAX_PORTRAIT_WORKERS = 6


def ensure_duckdb(force: bool = False) -> Path:
    SYNC_DIR.mkdir(parents=True, exist_ok=True)
    if DUCKDB_PATH.exists() and DUCKDB_PATH.stat().st_size > 1_000_000 and not force:
        return DUCKDB_PATH
    print(f"Downloading Transfermarkt dump → {DUCKDB_PATH}")
    tmp = DUCKDB_PATH.with_suffix(".duckdb.partial")
    with requests.get(DUCKDB_URL, stream=True, timeout=120) as response:
        response.raise_for_status()
        total = int(response.headers.get("content-length") or 0)
        done = 0
        with tmp.open("wb") as handle:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                handle.write(chunk)
                done += len(chunk)
                if total:
                    pct = done * 100 // total
                    print(f"\r  {pct}% ({done // 1_000_000} MB)", end="", flush=True)
    print()
    tmp.replace(DUCKDB_PATH)
    return DUCKDB_PATH


def portrait_ref(player_id: str) -> str:
    return f"portrait:{player_id}"


def has_local_portrait(player_id: str) -> bool:
    path = PORTRAIT_DIR / f"{player_id}.png"
    return path.exists() and path.stat().st_size > 500


def normalize_portrait_png(data: bytes, size: int = PORTRAIT_SIZE) -> bytes:
    from PIL import Image

    image = Image.open(BytesIO(data)).convert("RGBA")
    width, height = image.size
    side = min(width, height)
    left = (width - side) // 2
    top = max(0, (height - side) // 2 - int(side * 0.08))
    bottom = min(height, top + side)
    top = max(0, bottom - side)
    cropped = image.crop((left, top, left + side, bottom))
    resized = cropped.resize((size, size), Image.Resampling.LANCZOS)
    flattened = Image.new("RGB", resized.size, (255, 255, 255))
    flattened.paste(resized, mask=resized.split()[-1])
    output = BytesIO()
    flattened.save(output, format="PNG", optimize=True, compress_level=9)
    return output.getvalue()


def download_portrait(player_id: str, image_url: str | None) -> bool:
    if has_local_portrait(player_id):
        return True
    if not image_url:
        return False
    try:
        response = requests.get(image_url, headers=HEADERS, timeout=20)
        response.raise_for_status()
        if not response.content:
            return False
        png = normalize_portrait_png(response.content)
        PORTRAIT_DIR.mkdir(parents=True, exist_ok=True)
        (PORTRAIT_DIR / f"{player_id}.png").write_bytes(png)
        return True
    except Exception:
        return False


def slim_from_row(row: dict, old: dict | None = None) -> dict:
    player_id = str(row["player_id"])
    citizenship = (row.get("country_of_citizenship") or "").strip()
    old_nats = list((old or {}).get("nationality") or [])
    if citizenship:
        if old_nats and citizenship in old_nats and len(old_nats) > 1:
            nationality = old_nats
        else:
            nationality = [citizenship]
    else:
        nationality = old_nats

    position = (row.get("sub_position") or row.get("position") or (old or {}).get("position") or "").strip()
    name = (row.get("name") or (old or {}).get("name") or player_id).strip()
    market_value = row.get("market_value_in_eur")
    if market_value is None and old:
        market_value = old.get("marketValue")

    if has_local_portrait(player_id):
        image = portrait_ref(player_id)
    else:
        image = (old or {}).get("image") or row.get("image_url") or ""

    return {
        "id": player_id,
        "name": name,
        "image": image,
        "position": position,
        "nationality": nationality,
        "marketValue": market_value,
    }


def field_changes(old: dict, new: dict) -> dict:
    changes = {}
    for key, label in (
        ("name", "name"),
        ("position", "position"),
        ("marketValue", "marketValue"),
        ("nationality", "nationality"),
    ):
        if old.get(key) != new.get(key):
            changes[label] = {"from": old.get(key), "to": new.get(key)}
    return changes


def free_agent_club(existing_clubs: list[dict]) -> dict:
    for club in existing_clubs:
        if str(club.get("id")) == FREE_AGENT_ID:
            return club
    return {
        "id": FREE_AGENT_ID,
        "name": FREE_AGENT_NAME,
        "officialName": FREE_AGENT_NAME,
        "aliases": [FREE_AGENT_NAME, "Free Agents", "Without Club"],
        "players": [],
    }


def sync(dry_run: bool = False, skip_portraits: bool = False, refresh_dump: bool = False) -> dict:
    try:
        import duckdb
    except ImportError:
        sys.exit("duckdb package required: pip3 install duckdb")

    ensure_duckdb(force=refresh_dump)
    con = duckdb.connect(str(DUCKDB_PATH), read_only=True)

    current_season = con.execute(
        "select last_season from players where last_season is not null order by last_season desc limit 1"
    ).fetchone()[0]
    print(f"Using last_season = {current_season}")

    with DATABASE_PATH.open(encoding="utf-8") as handle:
        database = json.load(handle)

    tracked_clubs = [c for c in database["clubs"] if str(c.get("id")) != FREE_AGENT_ID]
    club_ids = [str(c["id"]) for c in tracked_clubs]
    club_id_set = set(club_ids)

    old_by_id: dict[str, tuple[str, dict]] = {}
    for club in database["clubs"]:
        for player in club.get("players", []):
            old_by_id[str(player["id"])] = (str(club["id"]), player)

    # All active players currently at one of our clubs.
    rows = con.execute(
        """
        select
          cast(player_id as varchar) as player_id,
          name,
          current_club_id,
          current_club_name,
          position,
          sub_position,
          country_of_citizenship,
          market_value_in_eur,
          image_url,
          last_season
        from players
        where last_season = ?
          and current_club_id in (select unnest(?))
        """,
        [current_season, club_ids],
    ).fetchall()
    cols = [
        "player_id",
        "name",
        "current_club_id",
        "current_club_name",
        "position",
        "sub_position",
        "country_of_citizenship",
        "market_value_in_eur",
        "image_url",
        "last_season",
    ]
    live_rows = [dict(zip(cols, row)) for row in rows]

    live_by_club: dict[str, list[dict]] = {cid: [] for cid in club_ids}
    live_ids: set[str] = set()
    for row in live_rows:
        pid = str(row["player_id"])
        cid = str(row["current_club_id"])
        live_ids.add(pid)
        live_by_club.setdefault(cid, []).append(row)

    report = {
        "syncedAt": datetime.now(timezone.utc).isoformat(),
        "season": current_season,
        "clubTransfers": [],
        "fieldUpdates": [],
        "added": [],
        "freeAgents": [],
        "departed": [],
        "unchanged": 0,
        "portraitsFetched": [],
        "portraitsFailed": [],
    }

    new_players_needing_portraits: list[tuple[str, str | None]] = []

    # Rebuild tracked clubs' squads.
    new_clubs: list[dict] = []
    for club in tracked_clubs:
        cid = str(club["id"])
        squad_rows = live_by_club.get(cid, [])
        # Stable-ish order: market value desc then name.
        squad_rows.sort(
            key=lambda r: (-(r.get("market_value_in_eur") or 0), r.get("name") or "")
        )
        new_players: list[dict] = []
        for row in squad_rows:
            pid = str(row["player_id"])
            old_club_id, old_player = old_by_id.get(pid, (None, None))
            slim = slim_from_row(row, old_player)
            new_players.append(slim)

            if old_player is None:
                report["added"].append(
                    {
                        "id": pid,
                        "name": slim["name"],
                        "clubId": cid,
                        "clubName": club["name"],
                        "position": slim["position"],
                        "marketValue": slim["marketValue"],
                    }
                )
                new_players_needing_portraits.append((pid, row.get("image_url")))
            else:
                if old_club_id != cid and old_club_id != FREE_AGENT_ID:
                    report["clubTransfers"].append(
                        {
                            "id": pid,
                            "name": slim["name"],
                            "fromClubId": old_club_id,
                            "toClubId": cid,
                            "toClubName": club["name"],
                        }
                    )
                changes = field_changes(old_player, slim)
                if changes:
                    report["fieldUpdates"].append(
                        {"id": pid, "name": slim["name"], "clubId": cid, "changes": changes}
                    )
                if not changes and old_club_id == cid:
                    report["unchanged"] += 1

        updated_club = dict(club)
        updated_club["players"] = new_players
        new_clubs.append(updated_club)

    # Orphans: were in our DB, not on any current squad of our clubs.
    orphan_ids = [pid for pid in old_by_id if pid not in live_ids and old_by_id[pid][0] != FREE_AGENT_ID]

    # Batch-load orphan metadata from the dump.
    orphan_meta: dict[str, dict] = {}
    digit_orphans = [int(pid) for pid in orphan_ids if pid.isdigit()]
    if digit_orphans:
        meta_rows = con.execute(
            """
            select
              cast(player_id as varchar),
              name,
              current_club_id,
              current_club_name,
              position,
              sub_position,
              country_of_citizenship,
              market_value_in_eur,
              image_url,
              last_season
            from players
            where player_id in (select unnest(?::INTEGER[]))
            """,
            [digit_orphans],
        ).fetchall()
        for row in meta_rows:
            orphan_meta[str(row[0])] = dict(zip(cols, row))

    free_agents: list[dict] = []
    # Keep previous free agents who are still not on a tracked squad.
    prev_fa = next((c for c in database["clubs"] if str(c.get("id")) == FREE_AGENT_ID), None)
    if prev_fa:
        for player in prev_fa.get("players", []):
            pid = str(player["id"])
            if pid in live_ids:
                continue  # rejoined a tracked club
            meta = orphan_meta.get(pid)
            if meta and str(meta.get("last_season")) == current_season and str(meta.get("current_club_id")) not in club_id_set:
                # Signed for an untracked club — drop.
                report["departed"].append(
                    {
                        "id": pid,
                        "name": player.get("name"),
                        "reason": "joined_untracked_club",
                        "clubId": meta.get("current_club_id"),
                        "clubName": meta.get("current_club_name"),
                    }
                )
                continue
            free_agents.append(slim_from_row(meta, player) if meta else player)

    for pid in orphan_ids:
        old_club_id, old_player = old_by_id[pid]
        meta = orphan_meta.get(pid)
        if meta is None:
            # Unknown to dump — keep as free agent with last known data.
            free_agents.append(old_player)
            report["freeAgents"].append(
                {
                    "id": pid,
                    "name": old_player.get("name"),
                    "fromClubId": old_club_id,
                    "reason": "missing_from_dataset",
                }
            )
            continue

        cur_club = str(meta.get("current_club_id") or "")
        season = str(meta.get("last_season") or "")
        club_name = (meta.get("current_club_name") or "").strip()

        if season == current_season and cur_club and cur_club not in club_id_set:
            report["departed"].append(
                {
                    "id": pid,
                    "name": meta.get("name") or old_player.get("name"),
                    "reason": "joined_untracked_club",
                    "clubId": cur_club,
                    "clubName": club_name or None,
                }
            )
            continue

        # No longer active at a tracked club this season → free agent.
        slim = slim_from_row(meta, old_player)
        free_agents.append(slim)
        report["freeAgents"].append(
            {
                "id": pid,
                "name": slim["name"],
                "fromClubId": old_club_id,
                "reason": "no_current_tracked_club",
                "lastSeason": season,
                "datasetClubId": cur_club or None,
                "datasetClubName": club_name or None,
            }
        )
        if not has_local_portrait(pid) and meta.get("image_url"):
            new_players_needing_portraits.append((pid, meta.get("image_url")))

    # Deduplicate free agents by id (keep highest market value).
    fa_by_id: dict[str, dict] = {}
    for player in free_agents:
        pid = str(player["id"])
        prev = fa_by_id.get(pid)
        if prev is None or (player.get("marketValue") or 0) >= (prev.get("marketValue") or 0):
            fa_by_id[pid] = player
    free_agents = sorted(
        fa_by_id.values(),
        key=lambda p: (-(p.get("marketValue") or 0), p.get("name") or ""),
    )

    fa_club = free_agent_club(database["clubs"])
    fa_club["players"] = free_agents
    new_clubs.append(fa_club)

    report["summary"] = {
        "clubs": len(new_clubs),
        "playersAtClubs": sum(len(c["players"]) for c in new_clubs if c["id"] != FREE_AGENT_ID),
        "freeAgents": len(free_agents),
        "added": len(report["added"]),
        "clubTransfers": len(report["clubTransfers"]),
        "fieldUpdates": len(report["fieldUpdates"]),
        "departed": len(report["departed"]),
        "unchanged": report["unchanged"],
    }

    print("Summary:")
    for key, value in report["summary"].items():
        print(f"  {key}: {value}")

    if not skip_portraits and new_players_needing_portraits:
        # Unique by id.
        pending = {}
        for pid, url in new_players_needing_portraits:
            if not has_local_portrait(pid):
                pending[pid] = url
        print(f"Fetching {len(pending)} portraits…")
        fetched = failed = 0
        with ThreadPoolExecutor(max_workers=MAX_PORTRAIT_WORKERS) as pool:
            futures = {
                pool.submit(download_portrait, pid, url): pid for pid, url in pending.items()
            }
            for index, future in enumerate(as_completed(futures), start=1):
                pid = futures[future]
                ok = False
                try:
                    ok = future.result()
                except Exception:
                    ok = False
                if ok:
                    fetched += 1
                    report["portraitsFetched"].append(pid)
                else:
                    failed += 1
                    report["portraitsFailed"].append(pid)
                if index % 50 == 0 or index == len(futures):
                    print(f"  portraits [{index}/{len(futures)}] ok={fetched} fail={failed}")
        # Point image fields at local portraits where we just saved them.
        for club in new_clubs:
            for player in club["players"]:
                if has_local_portrait(str(player["id"])):
                    player["image"] = portrait_ref(str(player["id"]))
        report["summary"]["portraitsFetched"] = fetched
        report["summary"]["portraitsFailed"] = failed

    database_out = {
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "clubs": new_clubs,
    }

    SYNC_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote report → {REPORT_PATH}")

    if dry_run:
        preview = SYNC_DIR / "ClubDatabase.synced.dryrun.json"
        preview.write_text(json.dumps(database_out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Dry run — wrote preview → {preview}")
        return report

    # Backup then replace.
    backup = SYNC_DIR / f"ClubDatabase.backup.{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.json"
    shutil.copy2(DATABASE_PATH, backup)
    DATABASE_PATH.write_text(json.dumps(database_out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {DATABASE_PATH}")
    print(f"Backup → {backup}")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="Don't write ClubDatabase.json")
    parser.add_argument("--skip-portraits", action="store_true", help="Skip downloading new portraits")
    parser.add_argument("--refresh-dump", action="store_true", help="Re-download the DuckDB dump")
    args = parser.parse_args()
    sync(dry_run=args.dry_run, skip_portraits=args.skip_portraits, refresh_dump=args.refresh_dump)


if __name__ == "__main__":
    main()
