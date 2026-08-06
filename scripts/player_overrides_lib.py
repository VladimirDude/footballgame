#!/usr/bin/env python3
"""
Shared helpers: apply player_overrides.json onto a ClubDatabase dict.

Override entry shape (all fields optional except player identity):
  {
    "playerId": "557149",          # preferred
    "playerName": "Kang-in Lee",   # fallback lookup / human label
    "moveToClubId": "13",          # preferred club target
    "moveToClubName": "Atlético de Madrid",
    "set": {
      "name": "Kang-in Lee",
      "position": "Left Winger",
      "marketValue": 35000000,
      "nationality": ["Korea, South"]
    },
    "note": "optional comment"
  }
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = ROOT / "test" / "Database" / "ClubDatabase.json"
OVERRIDES_PATH = ROOT / "test" / "Database" / "player_overrides.json"

PLAYER_SET_KEYS = ("name", "position", "marketValue", "nationality", "image")


def load_database(path: Path = DATABASE_PATH) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def save_database(data: dict[str, Any], path: Path = DATABASE_PATH) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_overrides(path: Path = OVERRIDES_PATH) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    raw = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(raw, dict) and "overrides" in raw:
        return list(raw["overrides"])
    if isinstance(raw, list):
        return raw
    raise ValueError(f"Unexpected overrides format in {path}")


def save_overrides(overrides: list[dict[str, Any]], path: Path = OVERRIDES_PATH) -> None:
    payload = {
        "description": (
            "Manual player patches applied on top of ClubDatabase.json when publishing. "
            "Survives a full Transfermarkt re-fetch — re-applied by publish_remote_data.py."
        ),
        "overrides": overrides,
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _norm(s: str) -> str:
    import unicodedata

    collapsed = unicodedata.normalize("NFKD", s)
    collapsed = "".join(ch for ch in collapsed if not unicodedata.combining(ch))
    return " ".join(collapsed.casefold().split())


def find_player(
    data: dict[str, Any],
    *,
    player_id: str | None = None,
    player_name: str | None = None,
) -> tuple[dict[str, Any], dict[str, Any], int] | None:
    """Return (club, player, index_in_club.players) or None."""
    if player_id:
        for club in data["clubs"]:
            for i, player in enumerate(club["players"]):
                if str(player.get("id")) == str(player_id):
                    return club, player, i
    if player_name:
        needle = _norm(player_name)
        for club in data["clubs"]:
            for i, player in enumerate(club["players"]):
                if _norm(player.get("name", "")) == needle:
                    return club, player, i
        # Fuzzy contains match (single hit only).
        hits: list[tuple[dict[str, Any], dict[str, Any], int]] = []
        for club in data["clubs"]:
            for i, player in enumerate(club["players"]):
                if needle in _norm(player.get("name", "")):
                    hits.append((club, player, i))
        if len(hits) == 1:
            return hits[0]
        if len(hits) > 1:
            options = ", ".join(f"{p['name']} @ {c['name']} ({p['id']})" for c, p, _ in hits[:8])
            raise ValueError(f"Multiple players match '{player_name}': {options}")
    return None


def find_club(
    data: dict[str, Any],
    *,
    club_id: str | None = None,
    club_name: str | None = None,
) -> dict[str, Any] | None:
    if club_id:
        for club in data["clubs"]:
            if str(club.get("id")) == str(club_id):
                return club
    if club_name:
        needle = _norm(club_name)
        # 1) Exact name / official / alias
        for club in data["clubs"]:
            names = [club.get("name", ""), club.get("officialName") or ""] + list(club.get("aliases") or [])
            if any(_norm(n) == needle for n in names if n):
                return club
        # 2) Contains match — unique only; otherwise error with candidates
        hits: list[dict[str, Any]] = []
        for club in data["clubs"]:
            names = [club.get("name", ""), club.get("officialName") or ""] + list(club.get("aliases") or [])
            if any(needle in _norm(n) for n in names if n):
                hits.append(club)
        if len(hits) == 1:
            return hits[0]
        if len(hits) > 1:
            options = ", ".join(f"{c['name']} (id {c['id']})" for c in hits[:8])
            raise ValueError(
                f"Multiple clubs match '{club_name}': {options}. "
                "Use a fuller name or --club with the id."
            )
    return None


def apply_override(data: dict[str, Any], override: dict[str, Any]) -> str:
    """Mutate `data` in place. Returns a short human summary."""
    found = find_player(
        data,
        player_id=override.get("playerId"),
        player_name=override.get("playerName"),
    )
    if not found:
        identity = override.get("playerId") or override.get("playerName") or "?"
        raise ValueError(f"Player not found: {identity}")

    from_club, player, index = found
    player_id = str(player["id"])
    label = player.get("name", player_id)

    # Field updates (copy so we don't share refs across clubs).
    updated = dict(player)
    for key, value in (override.get("set") or {}).items():
        if key not in PLAYER_SET_KEYS:
            raise ValueError(f"Unsupported set field '{key}' (allowed: {', '.join(PLAYER_SET_KEYS)})")
        updated[key] = value

    target_club = from_club
    moved = False
    if override.get("moveToClubId") or override.get("moveToClubName"):
        target = find_club(
            data,
            club_id=override.get("moveToClubId"),
            club_name=override.get("moveToClubName"),
        )
        if not target:
            dest = override.get("moveToClubId") or override.get("moveToClubName")
            raise ValueError(f"Club not found: {dest}")
        if target["id"] != from_club["id"]:
            from_club["players"].pop(index)
            # Avoid duplicates if player already listed at destination.
            target["players"] = [p for p in target["players"] if str(p.get("id")) != player_id]
            target["players"].append(updated)
            target_club = target
            moved = True
        else:
            from_club["players"][index] = updated
    else:
        from_club["players"][index] = updated

    if moved:
        return f"{label}: {from_club['name']} → {target_club['name']}"
    return f"{label}: updated at {target_club['name']}"


def apply_all_overrides(
    data: dict[str, Any],
    overrides: list[dict[str, Any]] | None = None,
) -> list[str]:
    if overrides is None:
        overrides = load_overrides()
    summaries: list[str] = []
    for entry in overrides:
        summaries.append(apply_override(data, entry))
    return summaries
