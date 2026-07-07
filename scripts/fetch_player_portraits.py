#!/usr/bin/env python3
"""Download Transfermarkt player portraits and save normalized square PNGs."""

from __future__ import annotations

import json
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

import requests
from PIL import Image

BASE_URL = "https://transfermarkt-api.fly.dev"
PORTRAIT_SIZE = 128
MAX_WORKERS = 4
REQUEST_DELAY = 0.15
HEADERS = {"User-Agent": "FootballQuizApp/1.0 (vv.balbabyan@gmail.com)"}

ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = ROOT / "test" / "Database" / "ClubDatabase.json"
PORTRAIT_DIR = ROOT / "test" / "Database" / "PlayerPortraits"
MANIFEST_PATH = ROOT / "test" / "Database" / "portrait_manifest.json"


def portrait_ref(player_id: str) -> str:
    return f"portrait:{player_id}"


def is_portrait_ref(value: str | None) -> bool:
    return bool(value and value.startswith("portrait:"))


def fetch_profile_image_url(player_id: str) -> str | None:
    try:
        response = requests.get(
            f"{BASE_URL}/players/{player_id}/profile",
            headers=HEADERS,
            timeout=20,
        )
        response.raise_for_status()
        return response.json().get("imageUrl")
    except Exception:
        return None


def fetch_wikipedia_image(player_name: str) -> str | None:
    params = {
        "action": "query",
        "format": "json",
        "prop": "pageimages",
        "titles": player_name,
        "pithumbsize": 400,
        "piprop": "original",
    }
    try:
        response = requests.get(
            "https://en.wikipedia.org/w/api.php",
            params=params,
            headers=HEADERS,
            timeout=8,
        )
        response.raise_for_status()
        pages = response.json().get("query", {}).get("pages", {})
        for page in pages.values():
            original = page.get("original", {})
            if original.get("source"):
                return original["source"]
    except Exception:
        pass
    return None


def download_image(url: str) -> bytes | None:
    try:
        response = requests.get(url, headers=HEADERS, timeout=20)
        response.raise_for_status()
        if response.content:
            return response.content
    except Exception:
        pass
    return None


def normalize_portrait_png(data: bytes, size: int = PORTRAIT_SIZE) -> bytes:
    """Center-crop to square and resize for circular UI frames."""
    image = Image.open(BytesIO(data)).convert("RGBA")
    width, height = image.size
    side = min(width, height)
    left = (width - side) // 2
    # Transfermarkt portraits are face-forward; bias crop slightly upward.
    top = max(0, (height - side) // 2 - int(side * 0.08))
    bottom = min(height, top + side)
    top = max(0, bottom - side)
    cropped = image.crop((left, top, left + side, bottom))
    resized = cropped.resize((size, size), Image.Resampling.LANCZOS)
    # Flatten onto white for smaller PNGs (faces display on light/dark UIs).
    flattened = Image.new("RGB", resized.size, (255, 255, 255))
    flattened.paste(resized, mask=resized.split()[-1])
    output = BytesIO()
    flattened.save(output, format="PNG", optimize=True, compress_level=9)
    return output.getvalue()


def save_portrait(player_id: str, png_data: bytes) -> Path:
    PORTRAIT_DIR.mkdir(parents=True, exist_ok=True)
    path = PORTRAIT_DIR / f"{player_id}.png"
    path.write_bytes(png_data)
    return path


def process_player(player: dict) -> tuple[str, str, str]:
    """Returns (player_id, status, detail). status: ok | missing | error"""
    player_id = str(player["id"])
    player_name = player.get("name", player_id)
    out_path = PORTRAIT_DIR / f"{player_id}.png"

    if out_path.exists() and out_path.stat().st_size > 500:
        return player_id, "ok", "cached"

    image_url = fetch_profile_image_url(player_id)
    time.sleep(REQUEST_DELAY)

    if not image_url:
        image_url = fetch_wikipedia_image(player_name)
        time.sleep(REQUEST_DELAY)

    if not image_url:
        return player_id, "missing", "no source"

    raw = download_image(image_url)
    if not raw:
        return player_id, "missing", "download failed"

    try:
        png = normalize_portrait_png(raw)
        save_portrait(player_id, png)
        return player_id, "ok", "fetched"
    except Exception as exc:
        return player_id, "error", str(exc)


def collect_players(database: dict) -> list[dict]:
    seen: set[str] = set()
    players: list[dict] = []
    for club in database.get("clubs", []):
        for player in club.get("players", []):
            player_id = str(player["id"])
            if player_id in seen:
                continue
            seen.add(player_id)
            players.append(player)
    return players


def apply_portrait_refs(database: dict) -> None:
    for club in database.get("clubs", []):
        for player in club.get("players", []):
            player_id = str(player["id"])
            png_path = PORTRAIT_DIR / f"{player_id}.png"
            if png_path.exists() and png_path.stat().st_size > 500:
                player["image"] = portrait_ref(player_id)


def main():
    with DATABASE_PATH.open(encoding="utf-8") as handle:
        database = json.load(handle)

    players = collect_players(database)
    print(f"Processing portraits for {len(players)} players...")

    stats = {"ok": 0, "missing": 0, "error": 0, "cached": 0, "fetched": 0}
    missing_players: list[dict] = []

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(process_player, player): player for player in players}
        for index, future in enumerate(as_completed(futures), start=1):
            player = futures[future]
            player_id, status, detail = future.result()
            stats[status] = stats.get(status, 0) + 1
            if detail in stats:
                stats[detail] += 1
            if status != "ok":
                missing_players.append(
                    {"id": player_id, "name": player.get("name"), "reason": detail}
                )
            if index % 100 == 0 or index == len(players):
                print(
                    f"[{index}/{len(players)}] ok={stats['ok']} "
                    f"missing={stats['missing']} error={stats['error']}"
                )

    apply_portrait_refs(database)
    database["updatedAt"] = datetime.now(timezone.utc).isoformat()

    with DATABASE_PATH.open("w", encoding="utf-8") as handle:
        json.dump(database, handle, ensure_ascii=False, indent=2)

    manifest = {
        "updatedAt": database["updatedAt"],
        "totalPlayers": len(players),
        "portraitsSaved": stats["ok"],
        "missing": stats["missing"],
        "errors": stats["error"],
        "missingPlayers": missing_players[:200],
    }
    with MANIFEST_PATH.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)

    print(f"Done. Saved {stats['ok']} portraits to {PORTRAIT_DIR}")
    print(f"Missing: {stats['missing']} | Errors: {stats['error']}")


if __name__ == "__main__":
    main()
