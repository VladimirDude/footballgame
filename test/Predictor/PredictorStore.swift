import Foundation
import Combine

@MainActor
final class PredictorStore: ObservableObject {

    static let shared = PredictorStore()

    @Published private(set) var database: PLFixturesDatabase?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSimulatingSeason = false
    @Published private(set) var lastRefreshError: String?
    @Published var selectedGameweek: Int = 1
    @Published private(set) var cachedOdds: [String: PLModelOdds] = [:]
    @Published private(set) var cachedStandings: [PLStandingRow] = []
    @Published private(set) var cachedSeasonStats: PLSeasonStats = .empty

    private let defaults = UserDefaults.standard
    private let predictionsKey = "plPredictorPredictionsV1"
    private let simulationsKey = "plPredictorSimulationsV2"
    static let simulateOnlyKey = "predictorSimulateOnly"

    // In-memory mirror of the simulations UserDefaults blob so body/draw code
    // never pays for JSON decode on the main thread.
    private var simulationsCache: [String: PLMatchSimulation] = [:]

    private init() {
        database = Self.loadBundled()
        selectedGameweek = currentGameweekNumber() ?? 1
        simulationsCache = loadSimulationsFromDisk()
        refreshDerivedCaches()
        buildOddsCache()
    }

    private func buildOddsCache() {
        guard let db = database else { return }
        let store = ClubDataStore.shared
        Task.detached(priority: .userInitiated) {
            var result: [String: PLModelOdds] = [:]
            result.reserveCapacity(db.gameweeks.reduce(0) { $0 + $1.matches.count })
            for gameweek in db.gameweeks {
                for match in gameweek.matches {
                    if let odds = SquadStrengthModel.odds(
                        homeClubID: match.homeClubID,
                        awayClubID: match.awayClubID,
                        store: store
                    ) {
                        result[match.id] = odds
                    }
                }
            }
            await MainActor.run { self.cachedOdds = result }
        }
    }

    // MARK: - Public

    var season: String { database?.season ?? "2026/27" }

    var gameweeks: [PLGameweek] {
        database?.gameweeks ?? []
    }

    func gameweek(_ number: Int) -> PLGameweek? {
        gameweeks.first { $0.number == number }
    }

    func prediction(for gameweek: Int) -> PLGameweekPrediction {
        loadPrediction(gameweek: gameweek)
    }

    func setPick(_ pick: PLPick?, for match: PLMatch) {
        var prediction = loadPrediction(gameweek: match.gameweek)
        guard let gameweek = gameweek(match.gameweek), !prediction.isLocked(for: gameweek) else { return }

        if let pick {
            prediction.picks[match.id] = pick
        } else {
            prediction.picks.removeValue(forKey: match.id)
        }
        savePrediction(prediction, gameweek: match.gameweek)
        objectWillChange.send()
    }

    func lockPrediction(for number: Int) {
        guard let gameweek = gameweek(number) else { return }
        var prediction = loadPrediction(gameweek: number)
        guard prediction.isComplete(for: gameweek), prediction.submittedAt == nil else { return }
        prediction = PLGameweekPrediction(picks: prediction.picks, submittedAt: PLPredictorFormat.isoNow())
        savePrediction(prediction, gameweek: number)
        simulateGameweek(number)
        objectWillChange.send()
    }

    /// Run simulation without requiring predictions (simulate-only mode).
    func simulateOnlyGameweek(_ number: Int, reroll: Bool = false) {
        _ = reroll
        simulateGameweek(number)
        objectWillChange.send()
    }

    /// Clears picks, lock state, and simulations so the gameweek can be played again.
    func resetGameweek(_ number: Int) {
        savePrediction(.empty(), gameweek: number)
        clearSimulations(for: number)
        refreshDerivedCaches()
        objectWillChange.send()
    }

    func isPredictionLocked(for gameweek: Int) -> Bool {
        loadPrediction(gameweek: gameweek).submittedAt != nil
    }

    var simulateOnlyMode: Bool {
        defaults.bool(forKey: Self.simulateOnlyKey)
    }

    var simulatedMatchCount: Int {
        loadSimulations().count
    }

    var totalMatchCount: Int {
        gameweeks.reduce(0) { $0 + $1.matches.count }
    }

    var isSeasonFullySimulated: Bool {
        totalMatchCount > 0 && simulatedMatchCount >= totalMatchCount
    }

    func standings() -> [PLStandingRow] { cachedStandings }

    func seasonStats() -> PLSeasonStats { cachedSeasonStats }

    private func refreshDerivedCaches() {
        let simulations = loadSimulations()
        cachedStandings = PLStandingsCalculator.compute(gameweeks: gameweeks, simulations: simulations)
        cachedSeasonStats = PLSeasonStatsCalculator.compute(gameweeks: gameweeks, simulations: simulations)
    }

    /// Simulates every gameweek in the season.
    func simulateFullSeason(reroll: Bool = false) {
        guard !gameweeks.isEmpty else { return }
        isSimulatingSeason = true
        defer { isSimulatingSeason = false }

        let shouldReroll = reroll || isSeasonFullySimulated

        if shouldReroll {
            clearAllSimulations()
            incrementSeasonNonce()
            for gameweek in gameweeks {
                defaults.removeObject(forKey: simulationNonceKey(gameweek: gameweek.number))
            }
        }

        for gameweek in gameweeks {
            if shouldReroll || !isGameweekSimulated(gameweek.number) {
                simulateGameweek(gameweek.number)
            }
        }
        refreshDerivedCaches()
        objectWillChange.send()
    }

    func resetSeasonSimulations() {
        clearAllSimulations()
        refreshDerivedCaches()
        objectWillChange.send()
    }

    func simulation(for matchID: String) -> PLMatchSimulation? {
        loadSimulations()[matchID]
    }

    func result(for match: PLMatch) -> PLMatchResult? {
        simulation(for: match.id)?.result ?? match.result
    }

    func isGameweekSimulated(_ number: Int) -> Bool {
        guard let gameweek = gameweek(number) else { return false }
        let sims = loadSimulations()
        return gameweek.matches.allSatisfy { sims[$0.id] != nil }
    }

    func simulateGameweek(_ number: Int, reroll: Bool = false) {
        guard let gameweek = gameweek(number) else { return }
        _ = reroll
        // Bump the nonce on every run so re-simulating (or clearing then simulating
        // again) never replays the exact same seeded scorelines.
        incrementSimulationNonce(for: number)
        let store = ClubDataStore.shared
        var simulations = loadSimulations()
        let nonce = combinedSimulationNonce(gameweek: number)

        for match in gameweek.matches {
            guard
                let homeID = match.homeClubID,
                let awayID = match.awayClubID,
                let homeClub = store.club(id: homeID),
                let awayClub = store.club(id: awayID)
            else { continue }

            simulations[match.id] = MatchSimulator.simulate(
                match: match,
                homeSquad: homeClub.players,
                awaySquad: awayClub.players,
                season: season,
                nonce: nonce
            )
        }

        saveSimulations(simulations)
        refreshDerivedCaches()
        objectWillChange.send()
    }

    func score(for gameweek: PLGameweek) -> PLGameweekScore? {
        let prediction = loadPrediction(gameweek: gameweek.number)
        guard prediction.submittedAt != nil else { return nil }

        var points = 0
        var correct = 0
        var graded = 0
        for match in gameweek.matches {
            guard let result = result(for: match), let pick = prediction.picks[match.id] else { continue }
            graded += 1
            if pick.matches(result: result) {
                points += 3
                correct += 1
            }
        }
        guard graded > 0 else { return nil }
        return PLGameweekScore(points: points, maxPoints: gameweek.matches.count * 3, correct: correct, total: gameweek.matches.count)
    }

    func seasonPoints() -> Int {
        gameweeks.compactMap { score(for: $0)?.points }.reduce(0, +)
    }

    func refreshFromWeb(resetProgress: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastRefreshError = nil
        defer { isRefreshing = false }

        if resetProgress {
            resetAllProgress()
        }

        do {
            let fetched = try await PLFixtureFetcher.fetch()
            database = fetched
            selectedGameweek = currentGameweekNumber() ?? selectedGameweek
            simulationsCache = loadSimulationsFromDisk()
            refreshDerivedCaches()
            buildOddsCache()
        } catch {
            lastRefreshError = error.localizedDescription
        }
    }

    func currentGameweekNumber(now: Date = .now) -> Int? {
        guard let gameweeks = database?.gameweeks, !gameweeks.isEmpty else { return nil }

        if let active = gameweeks.first(where: { gw in
            guard let start = gw.kickoffDate else { return false }
            let end = PLPredictorFormat.parseISO(gw.endsAt) ?? start
            return now >= start.addingTimeInterval(-7 * 24 * 3600) && now <= end.addingTimeInterval(3 * 24 * 3600)
        }) {
            return active.number
        }

        if let upcoming = gameweeks.first(where: { gw in
            guard let start = gw.kickoffDate else { return false }
            return start > now
        }) {
            return upcoming.number
        }

        return gameweeks.last?.number
    }

    // MARK: - Persistence

    private struct StoredPredictions: Codable {
        var byKey: [String: PLGameweekPrediction]
    }

    private func predictionKey(gameweek: Int) -> String {
        "\(season)-gw\(gameweek)"
    }

    private func loadPrediction(gameweek: Int) -> PLGameweekPrediction {
        guard
            let data = defaults.data(forKey: predictionsKey),
            let stored = try? JSONDecoder().decode(StoredPredictions.self, from: data),
            let prediction = stored.byKey[predictionKey(gameweek: gameweek)]
        else {
            return .empty()
        }
        return prediction
    }

    private func savePrediction(_ prediction: PLGameweekPrediction, gameweek: Int) {
        var stored = StoredPredictions(byKey: [:])
        if
            let data = defaults.data(forKey: predictionsKey),
            let decoded = try? JSONDecoder().decode(StoredPredictions.self, from: data)
        {
            stored = decoded
        }
        stored.byKey[predictionKey(gameweek: gameweek)] = prediction
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: predictionsKey)
        }
    }

    private static func loadBundled() -> PLFixturesDatabase? {
        guard
            let url = Bundle.main.url(forResource: "PLFixtures", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(PLFixturesDatabase.self, from: data)
    }

    private struct StoredSimulations: Codable {
        var byMatchID: [String: PLMatchSimulation]
    }

    private func loadSimulationsFromDisk() -> [String: PLMatchSimulation] {
        guard
            let data = defaults.data(forKey: simulationsKey),
            let stored = try? JSONDecoder().decode(StoredSimulations.self, from: data)
        else { return [:] }
        return stored.byMatchID
    }

    private func loadSimulations() -> [String: PLMatchSimulation] { simulationsCache }

    private func saveSimulations(_ simulations: [String: PLMatchSimulation]) {
        simulationsCache = simulations
        let stored = StoredSimulations(byMatchID: simulations)
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: simulationsKey)
        }
    }

    private func clearSimulations(for gameweekNumber: Int) {
        guard let gameweek = gameweek(gameweekNumber) else { return }
        var simulations = loadSimulations()
        for match in gameweek.matches {
            simulations.removeValue(forKey: match.id)
        }
        saveSimulations(simulations)
    }

    private func simulationNonceKey(gameweek: Int) -> String {
        "plPredictorNonce-\(season)-gw\(gameweek)"
    }

    private func simulationNonce(for gameweek: Int) -> Int {
        defaults.integer(forKey: simulationNonceKey(gameweek: gameweek))
    }

    private func incrementSimulationNonce(for gameweek: Int) {
        let key = simulationNonceKey(gameweek: gameweek)
        defaults.set(simulationNonce(for: gameweek) + 1, forKey: key)
    }

    private let seasonNonceStorageKey = "plPredictorSeasonNonce"

    private func seasonNonce() -> Int {
        defaults.integer(forKey: seasonNonceStorageKey)
    }

    private func incrementSeasonNonce() {
        defaults.set(seasonNonce() + 1, forKey: seasonNonceStorageKey)
    }

    private func combinedSimulationNonce(gameweek: Int) -> Int {
        simulationNonce(for: gameweek) + seasonNonce() * 10_000
    }

    private func clearAllSimulations() {
        simulationsCache = [:]
        defaults.removeObject(forKey: simulationsKey)
    }

    private func resetAllProgress() {
        defaults.removeObject(forKey: predictionsKey)
        clearAllSimulations()
        for gameweek in gameweeks {
            defaults.removeObject(forKey: simulationNonceKey(gameweek: gameweek.number))
        }
        defaults.removeObject(forKey: seasonNonceStorageKey)
        selectedGameweek = currentGameweekNumber() ?? 1
        refreshDerivedCaches()
        objectWillChange.send()
    }
}

// MARK: - Web fetch + openfootball parse

enum PLFixtureFetcher {

    static let sourceURL = URL(
        string: "https://raw.githubusercontent.com/openfootball/england/master/2026-27/1-premierleague.txt"
    )!

    private static let teamDisplay: [String: String] = [
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
    ]

    private static let teamClubIDs: [String: String] = [
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
    ]

    private static let months: [String: Int] = [
        "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
        "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12,
    ]

    static func fetch() async throws -> PLFixturesDatabase {
        var request = URLRequest(url: sourceURL)
        request.setValue("FTMP/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return try parse(text: text)
    }

    static func parse(text: String) throws -> PLFixturesDatabase {
        let gameweeks = try parseGameweeks(text: text)
        guard !gameweeks.isEmpty else { throw URLError(.zeroByteResource) }

        return PLFixturesDatabase(
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            season: "2026/27",
            sourceURL: sourceURL.absoluteString,
            gameweeks: gameweeks
        )
    }

    private static func parseGameweeks(text: String) throws -> [PLGameweek] {
        var gameweeks: [PLGameweek] = []
        var currentGW: Int?
        var currentYear = 2026
        var currentDate: (year: Int, month: Int, day: Int)?
        var currentHour = 15
        var currentMinute = 0
        var matches: [PLMatch] = []

        func flushGameweek() {
            guard let number = currentGW, !matches.isEmpty else {
                matches = []
                return
            }
            let kickoffs = matches.map(\.kickoff)
            gameweeks.append(
                PLGameweek(
                    number: number,
                    startsAt: kickoffs.min() ?? "",
                    endsAt: kickoffs.max() ?? "",
                    matches: matches
                )
            )
            matches = []
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("▪ Matchday ") {
                flushGameweek()
                let numberText = line.replacingOccurrences(of: "▪ Matchday ", with: "")
                currentGW = Int(numberText)
                currentDate = nil
                currentHour = 15
                currentMinute = 0
                continue
            }

            if let date = parseDateLine(line, currentYear: &currentYear, previous: currentDate) {
                currentDate = date
                continue
            }

            guard let gw = currentGW, let date = currentDate else { continue }

            if let timed = parseTimedMatch(line) {
                currentHour = timed.hour
                currentMinute = timed.minute
                matches.append(
                    makeMatch(
                        gameweek: gw,
                        index: matches.count + 1,
                        home: timed.home,
                        away: timed.away,
                        year: date.year,
                        month: date.month,
                        day: date.day,
                        hour: timed.hour,
                        minute: timed.minute
                    )
                )
                continue
            }

            if let untimed = parseUntimedMatch(line) {
                matches.append(
                    makeMatch(
                        gameweek: gw,
                        index: matches.count + 1,
                        home: untimed.home,
                        away: untimed.away,
                        year: date.year,
                        month: date.month,
                        day: date.day,
                        hour: currentHour,
                        minute: currentMinute
                    )
                )
            }
        }

        flushGameweek()
        return gameweeks
    }

    private static func parseDateLine(
        _ line: String,
        currentYear: inout Int,
        previous: (year: Int, month: Int, day: Int)?
    ) -> (year: Int, month: Int, day: Int)? {
        let parts = line.split(separator: " ")
        guard parts.count == 3 || parts.count == 4 else { return nil }
        guard let month = months[String(parts[1])], let day = Int(parts[2]) else { return nil }

        if parts.count == 4, let year = Int(parts[3]) {
            currentYear = year
        } else if let previous, month < previous.month {
            currentYear += 1
        }

        return (currentYear, month, day)
    }

    private static func parseTimedMatch(_ line: String) -> (hour: Int, minute: Int, home: String, away: String)? {
        let pattern = #"^(\d{2}):(\d{2})\s+(.+?)\s+v\s+(.+?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 5,
              let hourRange = Range(match.range(at: 1), in: line),
              let minuteRange = Range(match.range(at: 2), in: line),
              let homeRange = Range(match.range(at: 3), in: line),
              let awayRange = Range(match.range(at: 4), in: line),
              let hour = Int(line[hourRange]),
              let minute = Int(line[minuteRange]) else {
            return nil
        }
        return (hour, minute, normalize(String(line[homeRange])), normalize(String(line[awayRange])))
    }

    private static func parseUntimedMatch(_ line: String) -> (home: String, away: String)? {
        let pattern = #"^(.+?)\s+v\s+(.+?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 3,
              let homeRange = Range(match.range(at: 1), in: line),
              let awayRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return (normalize(String(line[homeRange])), normalize(String(line[awayRange])))
    }

    private static func normalize(_ name: String) -> String {
        name.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    private static func makeMatch(
        gameweek: Int,
        index: Int,
        home: String,
        away: String,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> PLMatch {
        PLMatch(
            id: "gw\(gameweek)-m\(index)",
            gameweek: gameweek,
            kickoff: String(format: "%04d-%02d-%02dT%02d:%02d:00", year, month, day, hour, minute),
            homeTeam: teamDisplay[home] ?? home,
            awayTeam: teamDisplay[away] ?? away,
            homeClubID: teamClubIDs[home],
            awayClubID: teamClubIDs[away],
            result: nil
        )
    }
}
