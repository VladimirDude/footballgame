#!/usr/bin/env python3
"""
Sync ClubDatabase.json against the weekly Transfermarkt datasets dump
(https://github.com/dcaribou/transfermarkt-datasets).

Why not transfermarkt-api.fly.dev?
  That API scrapes transfermarkt.com live; when TM's CDN has no DNS A/AAAA
  records the API returns 500s. The DuckDB dump is the reliable weekly snapshot
  and uses the same player/club IDs we already store.

What it does:
  • Prefer live Transfermarkt squad pages for the current season (dump lags loans)
  • Fall back to the DuckDB dump's current_club_id when a live fetch fails
  • Update name / position / nationality / market value from the dump
  • Add new players who joined one of our clubs (+ download portrait)
  • Move players with no current club / stale season → Free Agent club
  • Drop players who transferred to a club we don't track
  • Re-apply test/Database/player_overrides.json at the end

Usage:
  python3 scripts/sync_club_database.py
  python3 scripts/sync_club_database.py --skip-portraits
  python3 scripts/sync_club_database.py --dry-run
  python3 scripts/sync_club_database.py --dump-only
"""

from __future__ import annotations

import argparse
import json
import re
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
WITHOUT_CLUB_IDS = {"515"}  # Transfermarkt "Without Club"
PORTRAIT_SIZE = 128
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-GB,en;q=0.9",
}
MAX_PORTRAIT_WORKERS = 6
LIVE_SQUAD_SLEEP_S = 0.35


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

    slim = {
        "id": player_id,
        "name": name,
        "image": image,
        "position": position,
        "nationality": nationality,
        "marketValue": market_value,
    }
    slim.update(profile_fields_from_row(row, old))
    return slim


def _iso_date(value) -> str | None:
    if value is None:
        return None
    if hasattr(value, "date"):
        return value.date().isoformat()
    text = str(value).strip()
    if not text:
        return None
    return text[:10]


def profile_fields_from_row(row: dict, old: dict | None = None) -> dict:
    """Optional profile demographics from the Transfermarkt dump."""
    fields: dict = {}

    dob = _iso_date(row.get("date_of_birth"))
    if dob:
        fields["dateOfBirth"] = dob
    elif old and old.get("dateOfBirth"):
        fields["dateOfBirth"] = old["dateOfBirth"]

    foot = (row.get("foot") or "").strip().lower()
    if foot in {"left", "right", "both"}:
        fields["foot"] = foot
    elif old and old.get("foot"):
        fields["foot"] = old["foot"]

    height = row.get("height_in_cm")
    if isinstance(height, (int, float)) and 140 <= int(height) <= 220:
        fields["heightCm"] = int(height)
    elif old and old.get("heightCm"):
        fields["heightCm"] = old["heightCm"]

    peak = row.get("highest_market_value_in_eur")
    if isinstance(peak, (int, float)) and int(peak) > 0:
        fields["highestMarketValue"] = int(peak)
    elif old and old.get("highestMarketValue"):
        fields["highestMarketValue"] = old["highestMarketValue"]

    birth = (row.get("country_of_birth") or "").strip()
    if birth:
        fields["countryOfBirth"] = birth
    elif old and old.get("countryOfBirth"):
        fields["countryOfBirth"] = old["countryOfBirth"]

    return fields


def field_changes(old: dict, new: dict) -> dict:
    changes = {}
    for key, label in (
        ("name", "name"),
        ("position", "position"),
        ("marketValue", "marketValue"),
        ("nationality", "nationality"),
        ("dateOfBirth", "dateOfBirth"),
        ("foot", "foot"),
        ("heightCm", "heightCm"),
        ("highestMarketValue", "highestMarketValue"),
        ("countryOfBirth", "countryOfBirth"),
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


def current_tm_saison_id(now: datetime | None = None) -> int:
    """Transfermarkt saison_id is the calendar year the season starts (July)."""
    now = now or datetime.now(timezone.utc)
    return now.year if now.month >= 7 else now.year - 1


def fetch_live_squad_ids(club_id: str, saison_id: int) -> list[str] | None:
    """Ordered unique player IDs from a club's kader page for `saison_id`."""
    url = f"https://www.transfermarkt.co.uk/x/kader/verein/{club_id}/saison_id/{saison_id}"
    try:
        response = requests.get(url, headers=HEADERS, timeout=30)
        response.raise_for_status()
    except Exception as exc:
        print(f"  ! live squad failed for club {club_id} (saison {saison_id}): {exc}")
        return None

    html = response.text
    ordered: list[str] = []
    seen: set[str] = set()
    for match in re.finditer(r"/([a-z0-9\-]+)/profil/spieler/(\d+)", html):
        slug, pid = match.group(1), match.group(2)
        if slug in {"verein", "startseite", "kader", "transferverein", "marktwertverlauf"}:
            continue
        if pid not in seen:
            seen.add(pid)
            ordered.append(pid)
    if not ordered:
        for match in re.finditer(r"/profil/spieler/(\d+)", html):
            pid = match.group(1)
            if pid not in seen:
                seen.add(pid)
                ordered.append(pid)
    return ordered


def fetch_live_squad_ids_with_fallback(club_id: str, saison_id: int) -> tuple[list[str], int | None]:
    """
    Prefer the current TM season. If that page is empty (common for leagues whose
    season year differs), fall back one season, then treat as fetch failure.
    Returns (player_ids, saison_used_or_none_if_failed).
    """
    for sid in (saison_id, saison_id - 1):
        ids = fetch_live_squad_ids(club_id, sid)
        if ids is None:
            return [], None
        if ids:
            return ids, sid
    return [], saison_id


def load_player_rows(con, player_ids: list[str]) -> dict[str, dict]:
    """Load dump metadata for an arbitrary set of player IDs."""
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
        "date_of_birth",
        "foot",
        "height_in_cm",
        "highest_market_value_in_eur",
        "country_of_birth",
    ]
    digit_ids = [int(pid) for pid in player_ids if pid.isdigit()]
    if not digit_ids:
        return {}
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
          last_season,
          date_of_birth,
          foot,
          height_in_cm,
          highest_market_value_in_eur,
          country_of_birth
        from players
        where player_id in (select unnest(?::INTEGER[]))
        """,
        [digit_ids],
    ).fetchall()
    return {str(row[0]): dict(zip(cols, row)) for row in rows}


def latest_transfer_club(con, player_ids: list[str]) -> dict[str, tuple[str | None, str | None]]:
    """player_id → (to_club_id, to_club_name) from newest transfer on/before today."""
    digit_ids = [int(pid) for pid in player_ids if pid.isdigit()]
    if not digit_ids:
        return {}
    rows = con.execute(
        """
        with latest as (
          select
            cast(player_id as varchar) as player_id,
            cast(to_club_id as varchar) as to_club_id,
            to_club_name,
            row_number() over (partition by player_id order by transfer_date desc) as rn
          from transfers
          where player_id in (select unnest(?::INTEGER[]))
            and transfer_date <= current_date
        )
        select player_id, to_club_id, to_club_name from latest where rn = 1
        """,
        [digit_ids],
    ).fetchall()
    return {str(r[0]): (str(r[1]) if r[1] is not None else None, r[2]) for r in rows}


def sync(
    dry_run: bool = False,
    skip_portraits: bool = False,
    refresh_dump: bool = False,
    dump_only: bool = False,
) -> dict:
    try:
        import duckdb
    except ImportError:
        sys.exit("duckdb package required: pip3 install duckdb")

    ensure_duckdb(force=refresh_dump)
    con = duckdb.connect(str(DUCKDB_PATH), read_only=True)

    current_season = con.execute(
        "select last_season from players where last_season is not null order by last_season desc limit 1"
    ).fetchone()[0]
    saison_id = current_tm_saison_id()
    print(f"Dump last_season = {current_season}; live TM saison_id = {saison_id}")

    with DATABASE_PATH.open(encoding="utf-8") as handle:
        database = json.load(handle)

    tracked_clubs = [c for c in database["clubs"] if str(c.get("id")) != FREE_AGENT_ID]
    club_ids = [str(c["id"]) for c in tracked_clubs]
    club_id_set = set(club_ids)

    old_by_id: dict[str, tuple[str, dict]] = {}
    for club in database["clubs"]:
        for player in club.get("players", []):
            old_by_id[str(player["id"])] = (str(club["id"]), player)

    report = {
        "syncedAt": datetime.now(timezone.utc).isoformat(),
        "season": current_season,
        "tmSaisonId": saison_id,
        "liveSquadSource": not dump_only,
        "clubTransfers": [],
        "fieldUpdates": [],
        "added": [],
        "freeAgents": [],
        "departed": [],
        "unchanged": 0,
        "liveSquadFailures": [],
        "portraitsFetched": [],
        "portraitsFailed": [],
    }

    # --- Build membership: live TM squads (preferred) or dump current_club ---
    live_by_club: dict[str, list[str]] = {cid: [] for cid in club_ids}
    if dump_only:
        rows = con.execute(
            """
            select cast(player_id as varchar), cast(current_club_id as varchar)
            from players
            where last_season = ?
              and current_club_id in (select unnest(?))
            """,
            [current_season, club_ids],
        ).fetchall()
        for pid, cid in rows:
            live_by_club.setdefault(str(cid), []).append(str(pid))
    else:
        print(f"Fetching live squads for {len(club_ids)} clubs (saison_id={saison_id})…")
        for index, cid in enumerate(club_ids, start=1):
            ids, used = fetch_live_squad_ids_with_fallback(cid, saison_id)
            if used is None:
                report["liveSquadFailures"].append(cid)
                rows = con.execute(
                    """
                    select cast(player_id as varchar)
                    from players
                    where last_season = ? and cast(current_club_id as varchar) = ?
                    """,
                    [current_season, cid],
                ).fetchall()
                live_by_club[cid] = [str(r[0]) for r in rows]
            elif not ids:
                # Empty even after fallback — use dump so game modes keep a squad.
                report["liveSquadFailures"].append(cid)
                rows = con.execute(
                    """
                    select cast(player_id as varchar)
                    from players
                    where last_season = ? and cast(current_club_id as varchar) = ?
                    """,
                    [current_season, cid],
                ).fetchall()
                live_by_club[cid] = [str(r[0]) for r in rows]
            else:
                live_by_club[cid] = ids
            if index % 25 == 0 or index == len(club_ids):
                print(f"  live squads [{index}/{len(club_ids)}]")
            time.sleep(LIVE_SQUAD_SLEEP_S)

    live_ids: set[str] = set()
    for cid, pids in live_by_club.items():
        live_ids.update(pids)

    # Metadata for everyone we need (live + old DB).
    meta_by_id = load_player_rows(con, sorted(live_ids | set(old_by_id)))
    transfer_club = latest_transfer_club(con, sorted(set(old_by_id) - live_ids))

    new_players_needing_portraits: list[tuple[str, str | None]] = []
    new_clubs: list[dict] = []

    for club in tracked_clubs:
        cid = str(club["id"])
        squad_pids = live_by_club.get(cid, [])

        # Attach dump rows for sorting by market value.
        def sort_key(pid: str):
            row = meta_by_id.get(pid) or {}
            return (-(row.get("market_value_in_eur") or 0), row.get("name") or pid)

        squad_pids = sorted(squad_pids, key=sort_key)
        new_players: list[dict] = []
        for pid in squad_pids:
            row = meta_by_id.get(pid)
            old_club_id, old_player = old_by_id.get(pid, (None, None))
            if row is None:
                # Brand-new to dump — keep prior record or synthesize a stub.
                if old_player is None:
                    slim = {
                        "id": pid,
                        "name": f"Player {pid}",
                        "image": portrait_ref(pid) if has_local_portrait(pid) else "",
                        "position": "",
                        "nationality": [],
                        "marketValue": None,
                    }
                else:
                    slim = slim_from_row(
                        {
                            "player_id": pid,
                            "name": old_player.get("name"),
                            "country_of_citizenship": (old_player.get("nationality") or [None])[0],
                            "sub_position": old_player.get("position"),
                            "position": old_player.get("position"),
                            "market_value_in_eur": old_player.get("marketValue"),
                            "image_url": None,
                        },
                        old_player,
                    )
            else:
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
                new_players_needing_portraits.append(
                    (pid, (row or {}).get("image_url") if row else None)
                )
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

    # Orphans: were in our DB, not on any current live/tracked squad.
    orphan_ids = [
        pid for pid in old_by_id if pid not in live_ids and old_by_id[pid][0] != FREE_AGENT_ID
    ]

    free_agents: list[dict] = []
    prev_fa = next((c for c in database["clubs"] if str(c.get("id")) == FREE_AGENT_ID), None)
    if prev_fa:
        for player in prev_fa.get("players", []):
            pid = str(player["id"])
            if pid in live_ids:
                continue  # rejoined a tracked club
            meta = meta_by_id.get(pid)
            to_club_id, to_club_name = transfer_club.get(pid, (None, None))
            effective_club = str(
                (to_club_id if to_club_id is not None else None)
                or (meta or {}).get("current_club_id")
                or ""
            )
            if (
                effective_club
                and effective_club not in WITHOUT_CLUB_IDS
                and effective_club not in club_id_set
                and str((meta or {}).get("last_season") or "") == str(current_season)
            ):
                report["departed"].append(
                    {
                        "id": pid,
                        "name": player.get("name"),
                        "reason": "joined_untracked_club",
                        "clubId": effective_club,
                        "clubName": to_club_name or (meta or {}).get("current_club_name"),
                    }
                )
                continue
            free_agents.append(slim_from_row(meta, player) if meta else player)

    for pid in orphan_ids:
        old_club_id, old_player = old_by_id[pid]
        meta = meta_by_id.get(pid)
        to_club_id, to_club_name = transfer_club.get(pid, (None, None))
        effective_club = str(
            (to_club_id if to_club_id is not None else None)
            or (meta or {}).get("current_club_id")
            or ""
        )
        club_name = (to_club_name or (meta or {}).get("current_club_name") or "").strip()
        season = str((meta or {}).get("last_season") or "")

        if (
            effective_club
            and effective_club not in WITHOUT_CLUB_IDS
            and effective_club not in club_id_set
            and (season == str(current_season) or to_club_id is not None)
        ):
            report["departed"].append(
                {
                    "id": pid,
                    "name": (meta or {}).get("name") or old_player.get("name"),
                    "reason": "joined_untracked_club",
                    "clubId": effective_club,
                    "clubName": club_name or None,
                }
            )
            continue

        # No longer at a tracked club → free agent (includes Without Club).
        slim = slim_from_row(meta, old_player) if meta else old_player
        free_agents.append(slim)
        report["freeAgents"].append(
            {
                "id": pid,
                "name": slim.get("name") if isinstance(slim, dict) else old_player.get("name"),
                "fromClubId": old_club_id,
                "reason": "no_current_tracked_club",
                "lastSeason": season,
                "datasetClubId": effective_club or None,
                "datasetClubName": club_name or None,
            }
        )
        if meta and not has_local_portrait(pid) and meta.get("image_url"):
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
        "liveSquadFailures": len(report["liveSquadFailures"]),
    }

    print("Summary:")
    for key, value in report["summary"].items():
        print(f"  {key}: {value}")

    if not skip_portraits and new_players_needing_portraits:
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

    # Manual overrides on top of the sync (survives dump refresh).
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from player_overrides_lib import apply_all_overrides, load_overrides

        overrides = load_overrides()
        if overrides:
            summaries = apply_all_overrides(database_out, overrides)
            report["overridesApplied"] = summaries
            print(f"Applied {len(summaries)} player overrides")
    except Exception as exc:
        print(f"Warning: could not apply player overrides: {exc}")

    SYNC_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote report → {REPORT_PATH}")

    if dry_run:
        preview = SYNC_DIR / "ClubDatabase.synced.dryrun.json"
        preview.write_text(json.dumps(database_out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Dry run — wrote preview → {preview}")
        return report

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
    parser.add_argument(
        "--dump-only",
        action="store_true",
        help="Skip live Transfermarkt squad pages (use dump current_club only)",
    )
    args = parser.parse_args()
    sync(
        dry_run=args.dry_run,
        skip_portraits=args.skip_portraits,
        refresh_dump=args.refresh_dump,
        dump_only=args.dump_only,
    )


if __name__ == "__main__":
    main()
