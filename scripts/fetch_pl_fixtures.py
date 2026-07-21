#!/usr/bin/env python3
"""Fetch Premier League 2026/27 fixtures from openfootball."""

from __future__ import annotations

import json
import re
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SOURCE_URL = (
    "https://raw.githubusercontent.com/openfootball/england/master/"
    "2026-27/1-premierleague.txt"
)
SEASON = "2026/27"

# Display names used in the app UI.
TEAM_DISPLAY: dict[str, str] = {
    "Arsenal FC": "Arsenal",
    "Aston Villa FC": "Aston Villa",
    "AFC Bournemouth": "Bournemouth",
    "Brentford FC": "Brentford",
    "Brighton & Hove Albion FC": "Brighton",
    "Chelsea FC": "Chelsea",
    "Coventry City FC": "Coventry",
    "Crystal Palace FC": "Crystal Palace",
    "Everton FC": "Everton",
    "Fulham FC": "Fulham",
    "Hull City AFC": "Hull",
    "Ipswich Town FC": "Ipswich",
    "Leeds United FC": "Leeds",
    "Liverpool FC": "Liverpool",
    "Manchester City FC": "Man City",
    "Manchester United FC": "Man United",
    "Newcastle United FC": "Newcastle",
    "Nottingham Forest FC": "Nott'm Forest",
    "Sunderland AFC": "Sunderland",
    "Tottenham Hotspur FC": "Tottenham",
}

TEAM_CLUB_IDS: dict[str, str] = {
    "Arsenal FC": "11",
    "Aston Villa FC": "405",
    "AFC Bournemouth": "989",
    "Brentford FC": "1148",
    "Brighton & Hove Albion FC": "1237",
    "Chelsea FC": "631",
    "Coventry City FC": "990",
    "Crystal Palace FC": "873",
    "Everton FC": "29",
    "Fulham FC": "931",
    "Hull City AFC": "3008",
    "Ipswich Town FC": "677",
    "Leeds United FC": "399",
    "Liverpool FC": "31",
    "Manchester City FC": "281",
    "Manchester United FC": "985",
    "Newcastle United FC": "762",
    "Nottingham Forest FC": "703",
    "Sunderland AFC": "289",
    "Tottenham Hotspur FC": "148",
}

DATE_RE = re.compile(r"^(\w{3}) (\w{3}) (\d{1,2})(?: (\d{4}))?$")
TIME_MATCH_RE = re.compile(r"^(\d{2}:\d{2})\s+(.+?)\s+v\s+(.+?)\s*$")
MATCH_RE = re.compile(r"^(.+?)\s+v\s+(.+?)\s*$")
MONTHS = {
    "Jan": 1,
    "Feb": 2,
    "Mar": 3,
    "Apr": 4,
    "May": 5,
    "Jun": 6,
    "Jul": 7,
    "Aug": 8,
    "Sep": 9,
    "Oct": 10,
    "Nov": 11,
    "Dec": 12,
}


def fetch_text() -> str:
    request = urllib.request.Request(
        SOURCE_URL,
        headers={"User-Agent": "FootballQuizApp/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def normalize_team(name: str) -> str:
    return re.sub(r"\s+", " ", name.strip())


def kickoff_iso(year: int, month: int, day: int, hour: int, minute: int) -> str:
    return f"{year:04d}-{month:02d}-{day:02d}T{hour:02d}:{minute:02d}:00"


def parse_fixtures(text: str) -> list[dict]:
    gameweeks: list[dict] = []
    current_gw: int | None = None
    current_year = 2026
    current_date: tuple[int, int, int] | None = None
    current_time = (15, 0)
    matches: list[dict] = []

    def flush_gameweek() -> None:
        nonlocal matches, current_gw
        if current_gw is None or not matches:
            matches = []
            return
        kickoffs = [match["kickoff"] for match in matches]
        gameweeks.append(
            {
                "number": current_gw,
                "startsAt": min(kickoffs),
                "endsAt": max(kickoffs),
                "matches": matches,
            }
        )
        matches = []

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        if line.startswith("▪ Matchday "):
            flush_gameweek()
            current_gw = int(line.replace("▪ Matchday ", ""))
            current_date = None
            current_time = (15, 0)
            continue

        date_match = DATE_RE.match(line)
        if date_match:
            _, month_name, day, year_text = date_match.groups()
            month = MONTHS[month_name]
            day = int(day)
            if year_text:
                current_year = int(year_text)
            elif current_date is not None and month < current_date[1]:
                current_year += 1
            current_date = (current_year, month, day)
            continue

        if current_gw is None or current_date is None:
            continue

        home: str
        away: str
        time_match = TIME_MATCH_RE.match(line)
        if time_match:
            time_text, home, away = time_match.groups()
            hour, minute = [int(part) for part in time_text.split(":")]
            current_time = (hour, minute)
        else:
            match = MATCH_RE.match(line)
            if not match:
                continue
            home, away = match.groups()
            hour, minute = current_time

        year, month, day = current_date
        home = normalize_team(home)
        away = normalize_team(away)
        matches.append(
            {
                "id": f"gw{current_gw}-m{len(matches) + 1}",
                "gameweek": current_gw,
                "kickoff": kickoff_iso(year, month, day, hour, minute),
                "homeTeam": TEAM_DISPLAY.get(home, home),
                "awayTeam": TEAM_DISPLAY.get(away, away),
                "homeClubID": TEAM_CLUB_IDS.get(home),
                "awayClubID": TEAM_CLUB_IDS.get(away),
                "result": None,
            }
        )

    flush_gameweek()
    return gameweeks


def main() -> None:
    text = fetch_text()
    gameweeks = parse_fixtures(text)

    payload = {
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "season": SEASON,
        "sourceURL": SOURCE_URL,
        "gameweeks": gameweeks,
    }

    output = Path(__file__).resolve().parents[1] / "test" / "Database" / "PLFixtures.json"
    with output.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)

    match_count = sum(len(gw["matches"]) for gw in gameweeks)
    print(f"Saved {len(gameweeks)} gameweeks ({match_count} fixtures) for {SEASON} to {output}")


if __name__ == "__main__":
    main()
