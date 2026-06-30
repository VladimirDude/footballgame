#!/usr/bin/env python3
"""Download club squads once and refresh test/ClubDatabase.json for the iOS app."""

import json
import subprocess
import time
from datetime import datetime, timezone

BASE_URL = "https://transfermarkt-api.fly.dev"
DELAY_SECONDS = 3

# Top 5 from each of Europe's big five leagues, Primeira Liga, plus Rangers & Celtic.
CLUBS = [
    # Premier League
    ("281", ["Manchester City", "Man City", "Man. City"]),
    ("11", ["Arsenal", "Arsenal FC"]),
    ("31", ["Liverpool", "Liverpool FC"]),
    ("631", ["Chelsea", "Chelsea FC"]),
    ("985", ["Manchester United", "Man United", "Man Utd", "Man. United"]),
    ("148", ["Tottenham", "Tottenham Hotspur", "Spurs"]),
    ("762", ["Newcastle United", "Newcastle"]),
    # La Liga
    ("418", ["Real Madrid", "Real Madrid CF"]),
    ("131", ["Barcelona", "FC Barcelona", "Barca"]),
    ("13", ["Atletico Madrid", "Atlético Madrid", "Atletico"]),
    ("1050", ["Villarreal", "Villarreal CF"]),
    ("681", ["Real Sociedad", "Real Sociedad de Fútbol"]),
    # Bundesliga
    ("27", ["Bayern Munich", "Bayern", "FC Bayern Munich", "FC Bayern"]),
    ("16", ["Borussia Dortmund", "Dortmund", "BVB"]),
    ("15", ["Bayer Leverkusen", "Leverkusen", "Bayer 04 Leverkusen"]),
    ("23826", ["RB Leipzig", "Leipzig"]),
    ("79", ["VfB Stuttgart", "Stuttgart"]),
    # Serie A
    ("46", ["Inter Milan", "Inter", "Internazionale", "FC Internazionale"]),
    ("5", ["AC Milan", "Milan"]),
    ("506", ["Juventus", "Juventus FC"]),
    ("6195", ["Napoli", "SSC Napoli"]),
    ("12", ["AS Roma", "Roma"]),
    # Ligue 1
    ("583", ["Paris Saint-Germain", "PSG", "Paris SG"]),
    ("162", ["AS Monaco", "Monaco"]),
    ("244", ["Olympique Marseille", "Marseille", "OM"]),
    ("1041", ["Olympique Lyon", "Lyon", "OL"]),
    ("1082", ["Lille", "LOSC Lille", "LOSC"]),
    # Primeira Liga
    ("294", ["Benfica", "SL Benfica"]),
    ("720", ["Porto", "FC Porto"]),
    ("336", ["Sporting CP", "Sporting Lisbon", "Sporting"]),
    ("1075", ["Braga", "SC Braga"]),
    ("2420", ["Vitória Guimarães", "Vitoria Guimaraes", "Vitória SC"]),
    # Scottish Premiership
    ("124", ["Rangers", "Rangers FC"]),
    ("371", ["Celtic", "Celtic FC"]),
]


def fetch_json(path: str, retries: int = 3) -> dict:
    for attempt in range(retries):
        result = subprocess.run(
            ["curl", "-s", f"{BASE_URL}{path}"],
            capture_output=True,
            text=True,
            check=True,
        )
        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            if attempt == retries - 1:
                raise RuntimeError(f"Invalid JSON from {path}: {result.stdout[:200]}") from exc
            time.sleep(DELAY_SECONDS)
            continue

        if "detail" in payload or "error" in payload:
            if attempt == retries - 1:
                raise RuntimeError(f"API error for {path}: {payload}")
            time.sleep(DELAY_SECONDS)
            continue

        return payload

    raise RuntimeError(f"Failed to fetch {path}")


def slim_player(player: dict) -> dict:
    return {
        "id": player["id"],
        "name": player["name"],
        "position": player["position"],
        "nationality": player.get("nationality") or [],
        "marketValue": player.get("marketValue"),
    }


def main() -> None:
    clubs = []

    for index, (club_id, aliases) in enumerate(CLUBS):
        print(f"[{index + 1}/{len(CLUBS)}] Fetching club {club_id}...")

        profile = fetch_json(f"/clubs/{club_id}/profile")
        time.sleep(DELAY_SECONDS)

        squad = fetch_json(f"/clubs/{club_id}/players")
        time.sleep(DELAY_SECONDS)

        players = squad.get("players")
        if not players:
            raise RuntimeError(f"No players returned for club {club_id} ({profile['name']})")

        clubs.append(
            {
                "id": club_id,
                "name": profile["name"],
                "officialName": profile.get("officialName"),
                "aliases": aliases,
                "players": [slim_player(p) for p in players],
            }
        )

    database = {
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "clubs": clubs,
    }

    output_path = "test/ClubDatabase.json"
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(database, handle, ensure_ascii=False, indent=2)

    player_count = sum(len(c["players"]) for c in clubs)
    print(f"Saved {len(clubs)} clubs and {player_count} players to {output_path}")


if __name__ == "__main__":
    main()
