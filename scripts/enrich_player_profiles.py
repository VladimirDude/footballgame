#!/usr/bin/env python3
"""Enrich ClubDatabase.json with profile demographics from the TM dump.

Does not change club membership — only fills optional fields:
dateOfBirth, foot, heightCm, highestMarketValue, countryOfBirth.

Usage:
  python3 scripts/enrich_player_profiles.py
  python3 scripts/enrich_player_profiles.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from sync_club_database import (  # noqa: E402
    DATABASE_PATH,
    DUCKDB_PATH,
    ensure_duckdb,
    load_player_rows,
    profile_fields_from_row,
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--refresh-dump", action="store_true")
    args = parser.parse_args()

    try:
        import duckdb
    except ImportError:
        sys.exit("duckdb package required: pip3 install duckdb")

    ensure_duckdb(force=args.refresh_dump)
    con = duckdb.connect(str(DUCKDB_PATH), read_only=True)

    with DATABASE_PATH.open(encoding="utf-8") as handle:
        database = json.load(handle)

    player_ids = [
        str(player["id"])
        for club in database["clubs"]
        for player in club.get("players", [])
    ]
    meta = load_player_rows(con, player_ids)

    updated = 0
    missing = 0
    for club in database["clubs"]:
        for player in club.get("players", []):
            pid = str(player["id"])
            row = meta.get(pid)
            if row is None:
                missing += 1
                continue
            fields = profile_fields_from_row(row, player)
            if not fields:
                continue
            before = {k: player.get(k) for k in fields}
            if before == fields:
                continue
            player.update(fields)
            updated += 1

    print(f"players={len(player_ids)} enriched={updated} missing_in_dump={missing}")
    if args.dry_run:
        print("dry-run — not writing")
        return

    with DATABASE_PATH.open("w", encoding="utf-8") as handle:
        json.dump(database, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"wrote {DATABASE_PATH}")


if __name__ == "__main__":
    main()
