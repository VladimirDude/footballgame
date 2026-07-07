#!/usr/bin/env python3
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

import requests

BASE_URL = "https://transfermarkt-api.fly.dev"
DELAY_SECONDS = 0.5
FETCH_WIKI_IMAGES = os.environ.get("FETCH_WIKI_IMAGES", "0") == "1"

TOP_5_LEAGUES = [
    ("GB1", "Premier League"),
    ("ES1", "LaLiga"),
    ("IT1", "Serie A"),
    ("L1", "Bundesliga"),
    ("FR1", "Ligue 1"),
]

# Entire leagues to include beyond the top 5.
FULL_EXTRA_LEAGUES = [
    ("BRA1", "Brasileiro Serie A"),
    ("NL1", "Eredivisie"),
]

# Curated clubs: (id, aliases)
CURATED_CLUBS = [
    # Copenhagen
    ("190", ["FC Copenhagen", "Copenhagen"]),
    # Saudi Pro League – top 6
    ("1114", ["Al-Hilal"]),
    ("18544", ["Al-Nassr"]),
    ("8023", ["Al-Ittihad"]),
    ("18487", ["Al-Ahli"]),
    ("9840", ["Al-Shabab"]),
    ("7732", ["Al-Ettifaq"]),
    # Japan – top 2
    ("828", ["Urawa Red Diamonds"]),
    ("3958", ["Vissel Kobe"]),
    # MLS – top 10
    ("69261", ["Inter Miami"]),
    ("1061", ["LA Galaxy"]),
    ("51828", ["Los Angeles FC", "LAFC"]),
    ("51663", ["Atlanta United"]),
    ("9636", ["Seattle Sounders"]),
    ("40058", ["New York City FC", "NYCFC"]),
    ("4291", ["Portland Timbers"]),
    ("11141", ["Toronto FC"]),
    ("813", ["Columbus Crew"]),
    ("623", ["New York Red Bulls"]),
    # Mexico
    ("3631", ["Club América", "America"]),
    # Argentina – top 3
    ("189", ["Boca Juniors"]),
    ("209", ["River Plate"]),
    ("1444", ["Racing Club"]),
    # Belgium – top 5
    ("2282", ["Club Brugge"]),
    ("58", ["Anderlecht"]),
    ("1184", ["Genk"]),
    ("3948", ["Union Saint-Gilloise"]),
    ("1096", ["Royal Antwerp"]),
    # Serbia – top 2
    ("159", ["Red Star Belgrade"]),
    ("669", ["Partizan"]),
    # Greece – top 5
    ("683", ["Olympiacos"]),
    ("265", ["Panathinaikos"]),
    ("2441", ["AEK Athens"]),
    ("1091", ["PAOK"]),
    ("605", ["Aris"]),
    # Turkey – top 5
    ("141", ["Galatasaray"]),
    ("36", ["Fenerbahce"]),
    ("114", ["Besiktas"]),
    ("449", ["Trabzonspor"]),
    ("6890", ["Basaksehir"]),
    # Switzerland – top 3
    ("452", ["Young Boys"]),
    ("26", ["FC Basel"]),
    ("260", ["FC Zürich"]),
]

# Portuguese & Scottish clubs kept from the original database.
LEGACY_EXTRA_CLUBS = [
    ("294", ["Benfica"]),
    ("720", ["Porto"]),
    ("336", ["Sporting CP"]),
    ("1075", ["Braga"]),
    ("2420", ["Vitória Guimarães"]),
    ("124", ["Rangers"]),
    ("371", ["Celtic"]),
]

KNOWN_ALIASES = {
    "281": ["Manchester City"],
    "11": ["Arsenal"],
    "31": ["Liverpool"],
    "631": ["Chelsea"],
    "985": ["Manchester United"],
    "148": ["Tottenham"],
    "418": ["Real Madrid"],
    "131": ["Barcelona"],
    "13": ["Atletico Madrid"],
    "27": ["Bayern Munich"],
    "16": ["Borussia Dortmund"],
    "15": ["Bayer Leverkusen"],
    "46": ["Inter Milan"],
    "5": ["AC Milan"],
    "506": ["Juventus"],
    "583": ["Paris Saint-Germain", "PSG"],
    "189": ["Boca Juniors"],
    "209": ["River Plate"],
    "69261": ["Inter Miami"],
    "3631": ["Club América", "America"],
    "610": ["Ajax"],
    "383": ["PSV"],
    "234": ["Feyenoord"],
    "614": ["Flamengo"],
    "199": ["Corinthians"],
    "1023": ["Palmeiras"],
    "141": ["Galatasaray"],
    "36": ["Fenerbahce"],
    "159": ["Red Star Belgrade"],
}


def get_wiki_image(player_name: str) -> str:
    url = "https://en.wikipedia.org/w/api.php"
    headers = {"User-Agent": "FootballQuizApp/1.0 (vv.balbabyan@gmail.com)"}
    params = {
        "action": "query",
        "format": "json",
        "prop": "pageimages",
        "titles": player_name,
        "pithumbsize": 400,
        "piprop": "original",
    }
    try:
        response = requests.get(url, params=params, headers=headers, timeout=5)
        response.raise_for_status()
        data = response.json()
        pages = data.get("query", {}).get("pages", {})
        for _, page_data in pages.items():
            if "original" in page_data:
                return page_data["original"]["source"]
    except Exception:
        pass
    return ""


def fetch_json(path: str, retries: int = 3) -> dict:
    for attempt in range(retries):
        try:
            response = requests.get(f"{BASE_URL}{path}", timeout=20)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            if attempt == retries - 1:
                print(f"  API Error for {path}: {e}")
            else:
                time.sleep(DELAY_SECONDS * (attempt + 1))
    return {}


def slim_player(player: dict) -> dict:
    image_url = player.get("image") or ""
    if not image_url and FETCH_WIKI_IMAGES:
        image_url = get_wiki_image(player["name"])

    player_id = str(player["id"])
    portrait_path = Path(__file__).resolve().parents[1] / "test" / "Database" / "PlayerPortraits" / f"{player_id}.png"
    if portrait_path.exists() and portrait_path.stat().st_size > 500:
        image_url = f"portrait:{player_id}"

    return {
        "id": player_id,
        "name": player["name"],
        "image": image_url or "",
        "position": player["position"],
        "nationality": player.get("nationality") or [],
        "marketValue": player.get("marketValue"),
    }


def build_aliases(club_id: str, club_name: str) -> list[str]:
    if club_id in KNOWN_ALIASES:
        return KNOWN_ALIASES[club_id]

    aliases = [club_name]
    for suffix in (" FC", " CF", " SC", " AFC", " OSC", " BV", " AC", " SFC"):
        if club_name.endswith(suffix):
            aliases.append(club_name[: -len(suffix)].strip())
    return list(dict.fromkeys(aliases))


def collect_club_ids() -> list[tuple[str, list[str]]]:
    clubs: list[tuple[str, list[str]]] = []
    seen: set[str] = set()

    for league_id, league_name in TOP_5_LEAGUES:
        print(f"Loading clubs from {league_name} ({league_id})...")
        payload = fetch_json(f"/competitions/{league_id}/clubs")
        for club in payload.get("clubs", []):
            club_id = str(club["id"])
            if club_id in seen:
                continue
            seen.add(club_id)
            clubs.append((club_id, build_aliases(club_id, club["name"])))
        time.sleep(DELAY_SECONDS)

    for league_id, league_name in FULL_EXTRA_LEAGUES:
        print(f"Loading clubs from {league_name} ({league_id})...")
        payload = fetch_json(f"/competitions/{league_id}/clubs")
        for club in payload.get("clubs", []):
            club_id = str(club["id"])
            if club_id in seen:
                continue
            seen.add(club_id)
            clubs.append((club_id, build_aliases(club_id, club["name"])))
        time.sleep(DELAY_SECONDS)

    for club_id, aliases in CURATED_CLUBS + LEGACY_EXTRA_CLUBS:
        if club_id in seen:
            continue
        seen.add(club_id)
        clubs.append((club_id, aliases))

    return clubs


def fetch_club(club_id: str, aliases: list[str]) -> dict:
    profile = fetch_json(f"/clubs/{club_id}/profile")
    squad = fetch_json(f"/clubs/{club_id}/players")
    players = squad.get("players", [])
    return {
        "id": club_id,
        "name": profile.get("name", aliases[0]),
        "officialName": profile.get("officialName"),
        "aliases": aliases,
        "players": [slim_player(p) for p in players],
    }


def load_existing_database(path: str) -> dict | None:
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def main():
    output_dir = "test/Database"
    output_path = os.path.join(output_dir, "ClubDatabase.json")
    os.makedirs(output_dir, exist_ok=True)

    clubs_to_fetch = collect_club_ids()
    existing = load_existing_database(output_path)
    existing_by_id = {c["id"]: c for c in existing.get("clubs", [])} if existing else {}

    # Always keep every club already in the database.
    clubs_by_id = dict(existing_by_id)
    new_ids = [(club_id, aliases) for club_id, aliases in clubs_to_fetch if club_id not in clubs_by_id]

    print(f"Total target clubs: {len(clubs_to_fetch)}")
    print(f"Keeping {len(existing_by_id)} existing, fetching {len(new_ids)} new...")

    for index, (club_id, aliases) in enumerate(new_ids, start=1):
        print(f"[{index}/{len(new_ids)}] Fetching {aliases[0]}...")
        clubs_by_id[club_id] = fetch_club(club_id, aliases)
        time.sleep(DELAY_SECONDS)

    target_ids = {club_id for club_id, _ in clubs_to_fetch}
    extra_ids = [club_id for club_id in clubs_by_id if club_id not in target_ids]
    ordered_ids = [club_id for club_id, _ in clubs_to_fetch]
    ordered_ids.extend(sorted(extra_ids, key=lambda cid: clubs_by_id[cid]["name"]))
    clubs = [clubs_by_id[club_id] for club_id in ordered_ids if club_id in clubs_by_id]

    database = {
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "clubs": clubs,
    }

    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(database, handle, ensure_ascii=False, indent=2)

    print(f"Done! Saved {len(clubs)} clubs to {output_path}")


if __name__ == "__main__":
    main()
