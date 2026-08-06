#!/usr/bin/env python3
"""
Add or update a single-player override (transfer / field edit).

Examples:
  # Move Kang-in Lee to Atlético
  python3 scripts/patch_player.py --player "Kang-in Lee" --club "Atlético de Madrid"

  # Also change position / market value
  python3 scripts/patch_player.py --player "Kang-in Lee" --club "Atlético" \\
      --position "Left Winger" --value 35000000

  # Lookup only
  python3 scripts/patch_player.py --player "Kang-in Lee" --show

  # List saved overrides
  python3 scripts/patch_player.py --list

Then publish so devices pick it up:
  python3 scripts/publish_remote_data.py --upload
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow `import player_overrides_lib` when run as a script.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from player_overrides_lib import (  # noqa: E402
    DATABASE_PATH,
    OVERRIDES_PATH,
    apply_override,
    find_club,
    find_player,
    load_database,
    load_overrides,
    save_overrides,
)


def parse_value(raw: str | None) -> int | None:
    if raw is None:
        return None
    text = raw.strip().lower().replace(",", "").replace("_", "")
    if text.endswith("m"):
        return int(float(text[:-1]) * 1_000_000)
    if text.endswith("k"):
        return int(float(text[:-1]) * 1_000)
    return int(text)


def show_player(name_or_id: str) -> None:
    data = load_database()
    found = find_player(data, player_id=name_or_id, player_name=name_or_id)
    if not found:
        # Try id-only then name-only more carefully.
        found = find_player(data, player_id=name_or_id) or find_player(data, player_name=name_or_id)
    if not found:
        sys.exit(f"No player matching '{name_or_id}'")
    club, player, _ = found
    print(f"{player['name']}  (id {player['id']})")
    print(f"  club:     {club['name']} (id {club['id']})")
    print(f"  position: {player.get('position')}")
    print(f"  value:    {player.get('marketValue')}")
    print(f"  nation:   {', '.join(player.get('nationality') or [])}")


def upsert_override(args: argparse.Namespace) -> None:
    data = load_database()
    found = find_player(data, player_id=args.player, player_name=args.player)
    if not found:
        found = find_player(data, player_id=args.player) or find_player(data, player_name=args.player)
    if not found:
        sys.exit(f"No player matching '{args.player}'")

    club, player, _ = found
    player_id = str(player["id"])

    overrides = load_overrides()
    existing = next((o for o in overrides if str(o.get("playerId")) == player_id), None)
    entry = existing or {"playerId": player_id, "playerName": player["name"]}
    entry["playerId"] = player_id
    entry["playerName"] = player["name"]

    if args.club:
        try:
            target = find_club(data, club_id=args.club) or find_club(data, club_name=args.club)
        except ValueError as exc:
            sys.exit(str(exc))
        if not target:
            sys.exit(f"No club matching '{args.club}'")
        entry["moveToClubId"] = str(target["id"])
        entry["moveToClubName"] = target["name"]

    sets = dict(entry.get("set") or {})
    if args.name:
        sets["name"] = args.name
    if args.position:
        sets["position"] = args.position
    if args.value is not None:
        sets["marketValue"] = parse_value(args.value)
    if args.nationality:
        sets["nationality"] = [n.strip() for n in args.nationality.split("|") if n.strip()]
    if sets:
        entry["set"] = sets
    if args.note:
        entry["note"] = args.note

    if not entry.get("moveToClubId") and not entry.get("set"):
        sys.exit("Nothing to change — pass --club and/or --position/--value/--name/--nationality")

    # Validate against a copy of the DB.
    trial = load_database()
    summary = apply_override(trial, entry)

    if existing is None:
        overrides.append(entry)
    save_overrides(overrides)

    print(f"Saved override → {OVERRIDES_PATH}")
    print(f"  {summary}")
    print(json.dumps(entry, ensure_ascii=False, indent=2))
    print("\nPublish when ready:")
    print("  python3 scripts/publish_remote_data.py --upload")


def list_overrides() -> None:
    overrides = load_overrides()
    if not overrides:
        print(f"No overrides in {OVERRIDES_PATH}")
        return
    print(f"{len(overrides)} override(s) in {OVERRIDES_PATH}:\n")
    for entry in overrides:
        dest = entry.get("moveToClubName") or entry.get("moveToClubId") or "(same club)"
        sets = entry.get("set") or {}
        bits = [f"{k}={v}" for k, v in sets.items()]
        extra = f"  set: {', '.join(bits)}" if bits else ""
        print(f"- {entry.get('playerName')} ({entry.get('playerId')}) → {dest}{extra}")


def remove_override(player: str) -> None:
    overrides = load_overrides()
    before = len(overrides)
    overrides = [
        o
        for o in overrides
        if str(o.get("playerId")) != player and (o.get("playerName") or "").casefold() != player.casefold()
    ]
    if len(overrides) == before:
        sys.exit(f"No override for '{player}'")
    save_overrides(overrides)
    print(f"Removed override for '{player}'. Remaining: {len(overrides)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--player", help="Player name or id")
    parser.add_argument("--club", help="Move to this club (name or id)")
    parser.add_argument("--position", help="Set position string")
    parser.add_argument("--value", help="Set market value (35000000 or 35m)")
    parser.add_argument("--name", help="Rename player")
    parser.add_argument("--nationality", help="Pipe-separated nations, e.g. 'Korea, South'")
    parser.add_argument("--note", help="Optional comment stored with the override")
    parser.add_argument("--show", action="store_true", help="Print current DB row and exit")
    parser.add_argument("--list", action="store_true", help="List saved overrides")
    parser.add_argument("--remove", action="store_true", help="Delete override for --player")
    args = parser.parse_args()

    if args.list:
        list_overrides()
        return
    if not args.player:
        parser.error("--player is required (unless using --list)")
    if args.show:
        show_player(args.player)
        return
    if args.remove:
        remove_override(args.player)
        return
    upsert_override(args)


if __name__ == "__main__":
    main()
