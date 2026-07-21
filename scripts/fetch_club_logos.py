#!/usr/bin/env python3
"""Download Transfermarkt club crests and save normalized PNGs."""

from __future__ import annotations

import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

import requests
from PIL import Image

LOGO_SIZE = 128
MAX_WORKERS = 6
REQUEST_DELAY = 0.08
HEADERS = {"User-Agent": "FootballQuizApp/1.0 (vv.balbabyan@gmail.com)"}
CDN_URL = "https://tmssl.akamaized.net/images/wappen/head/{club_id}.png"

ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = ROOT / "test" / "Database" / "ClubDatabase.json"
LOGO_DIR = ROOT / "test" / "Database" / "ClubLogos"
MANIFEST_PATH = ROOT / "test" / "Database" / "club_logo_manifest.json"


def logo_filename(club_id: str) -> str:
    return f"club-{club_id}.png"


def logo_ref(club_id: str) -> str:
    return f"logo:{club_id}"


def download_logo(club_id: str) -> bytes | None:
    try:
        response = requests.get(
            CDN_URL.format(club_id=club_id),
            headers=HEADERS,
            timeout=20,
        )
        response.raise_for_status()
        if response.content and len(response.content) > 200:
            return response.content
    except Exception:
        pass
    return None


def normalize_logo_png(data: bytes, size: int = LOGO_SIZE, content_scale: float = 0.84) -> bytes:
    """Trim transparent margins, scale to a consistent visual weight, center on white."""
    image = Image.open(BytesIO(data)).convert("RGBA")

    alpha = image.split()[-1]
    bbox = alpha.getbbox()
    if bbox:
        image = image.crop(bbox)

    content_size = max(1, int(size * content_scale))
    width, height = image.size
    scale = min(content_size / width, content_size / height)
    new_width = max(1, int(width * scale))
    new_height = max(1, int(height * scale))
    resized = image.resize((new_width, new_height), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    offset_x = (size - new_width) // 2
    offset_y = (size - new_height) // 2
    canvas.paste(resized, (offset_x, offset_y), resized)

    output = BytesIO()
    canvas.save(output, format="PNG", optimize=True, compress_level=9)
    return output.getvalue()


def process_club(club: dict, force: bool = False) -> tuple[str, str, str]:
    club_id = str(club["id"])
    club_name = club.get("name", club_id)
    out_path = LOGO_DIR / logo_filename(club_id)

    if not force and out_path.exists() and out_path.stat().st_size > 200:
        return club_id, "ok", "cached"

    raw = download_logo(club_id)
    time.sleep(REQUEST_DELAY)

    if not raw:
        return club_id, "missing", club_name

    try:
        png = normalize_logo_png(raw)
        LOGO_DIR.mkdir(parents=True, exist_ok=True)
        out_path.write_bytes(png)
        return club_id, "ok", "fetched"
    except Exception as exc:
        return club_id, "error", str(exc)


def main() -> None:
    with DATABASE_PATH.open(encoding="utf-8") as handle:
        database = json.load(handle)

    clubs = database.get("clubs", [])
    force = "--force" in sys.argv
    print(f"Processing logos for {len(clubs)} clubs...")

    stats = {"ok": 0, "missing": 0, "error": 0, "cached": 0, "fetched": 0}
    missing_clubs: list[dict] = []

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(process_club, club, force): club for club in clubs}
        for index, future in enumerate(as_completed(futures), start=1):
            club = futures[future]
            club_id, status, detail = future.result()
            stats[status] = stats.get(status, 0) + 1
            if detail in stats:
                stats[detail] += 1
            if status != "ok":
                missing_clubs.append(
                    {"id": club_id, "name": club.get("name"), "reason": detail}
                )
            if index % 25 == 0 or index == len(clubs):
                print(
                    f"[{index}/{len(clubs)}] ok={stats['ok']} "
                    f"missing={stats['missing']} error={stats['error']}"
                )

    manifest = {
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "totalClubs": len(clubs),
        "logosSaved": stats["ok"],
        "missing": stats["missing"],
        "errors": stats["error"],
        "missingClubs": missing_clubs,
    }
    with MANIFEST_PATH.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)

    print(f"Done. Saved {stats['ok']} logos to {LOGO_DIR}")
    print(f"Missing: {stats['missing']} | Errors: {stats['error']}")


if __name__ == "__main__":
    main()
