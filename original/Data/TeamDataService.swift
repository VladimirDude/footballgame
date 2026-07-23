import Foundation

protocol TeamDataServiceProtocol {
    func fetchPlayers() -> [Player]
    func fetchGames() -> [Game]
}

struct TeamDataService: TeamDataServiceProtocol {

    func fetchPlayers() -> [Player] { Self.cognaizeRoster }
    func fetchGames() -> [Game] { Self.cognaizeGames }

    // MARK: - Roster

    static let cognaizeRoster: [Player] = {
        var r: [Player] = []
        r.append(Player(name: "Narek",  role: .player, goals: 9, assists: 3))
        r.append(Player(name: "Rob",    role: .player, goals: 7, assists: 5, bonusPoints: 2.5))
        r.append(Player(name: "Aro",    role: .player, goals: 6, assists: 6, bonusPoints: 1.0))
        r.append(Player(name: "Garo",   role: .player, goals: 5, assists: 4, bonusPoints: 0.5))
        r.append(Player(name: "Gagik",  role: .player, goals: 4, assists: 3, bonusPoints: 2.0))
        r.append(Player(name: "Rafo",   role: .player, goals: 4, assists: 2, bonusPoints: 0.5))
        r.append(Player(name: "Armen",  role: .player, goals: 3, assists: 5, bonusPoints: 1.0))
        r.append(Player(name: "Galust", role: .player, goals: 3, assists: 3, bonusPoints: 0.5))
        r.append(Player(name: "Vazgen", role: .player, goals: 3, assists: 2))
        r.append(Player(name: "Hayko",  role: .player, goals: 2, assists: 4, bonusPoints: 0.5))
        r.append(Player(name: "Seyran", role: .player, goals: 2, assists: 3))
        r.append(Player(name: "Hamo",   role: .player, goals: 2, assists: 2, bonusPoints: 0.5))
        r.append(Player(name: "Edo",    role: .player, goals: 1, assists: 3))
        r.append(Player(name: "David",  role: .player, goals: 1, assists: 2, bonusPoints: 0.5))
        r.append(Player(name: "Gugo",   role: .player, goals: 2, assists: 1, bonusPoints: 2.0))
        r.append(Player(name: "Grigor", role: .player, goals: 1, assists: 2, bonusPoints: 2.0))

        r.append(Player(name: "Erik",  role: .goalkeeper, bonusPoints: 2.0,
                         goalkeeperStats: GoalkeeperStats(matchesAttended: 8, goalsConceded: 12, cleanSheets: 3)))
        r.append(Player(name: "Artem", role: .goalkeeper, assists: 1, bonusPoints: 2.0,
                         goalkeeperStats: GoalkeeperStats(matchesAttended: 6, goalsConceded: 9, cleanSheets: 2)))

        r.append(Player(name: "Hakob", role: .coach,
                         coachInfo: CoachInfo(specialty: "Head Coach",
                                             tactics: "High-press 4-0 rotation with aggressive pivot play. Emphasizes quick transitions and set-piece mastery.",
                                             experience: "5 years coaching futsal at competitive level",
                                             philosophy: "\"Control the tempo, dominate the court. Every player is a playmaker.\"")))
        r.append(Player(name: "Vahag", role: .coach,
                         coachInfo: CoachInfo(specialty: "Assistant Coach & Fitness",
                                             tactics: "Defensive structure and counter-attack drills. Specializes in goalkeeper training and set-piece defense.",
                                             experience: "3 years assistant coaching, former GK",
                                             philosophy: "\"Fitness wins matches. Discipline wins championships.\"")))
        return r
    }()

    // MARK: - Games

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    static let cognaizeGames: [Game] = [
        Game(date: date(2025,4,12), opponent: "Mantashyants", goalsFor: 9, goalsAgainst: 0,
             scorers: ["Rafo","Narek x3","Armen x2","Galust","Rob"],
             goalDetails: [
                GoalDetail(time: "9:58",  scorer: "Rafo",   assist: "Rob"),
                GoalDetail(time: "11:20", scorer: "Narek",  assist: "Hamo"),
                GoalDetail(time: "16:49", scorer: "Armen",  assist: "Garo"),
                GoalDetail(time: "19:51", scorer: "Galust", assist: "Garo"),
                GoalDetail(time: "21:51", scorer: "Narek",  assist: "Gagik"),
                GoalDetail(time: "23:34", scorer: "Narek",  assist: "Vazgen"),
                GoalDetail(time: "41:40", scorer: "Rafo",   assist: "Aro"),
                GoalDetail(time: "43:04", scorer: "Rob",    assist: "Aro"),
                GoalDetail(time: "56:52", scorer: "Armen",  assist: "Rob"),
             ],
             mediaLinks: [
                MediaLink(title: "Full Match", urlString: "https://www.youtube.com/watch?v=Xh7MZICxHGw&t=1604s", type: .video),
             ]),
        Game(date: date(2025,4,5), opponent: "Mars", goalsFor: 3, goalsAgainst: 2,
             scorers: ["Garo","Hayko","Narek"],
             goalDetails: [
                GoalDetail(time: "34:29", scorer: "Garo",  assist: "Seyran"),
                GoalDetail(time: "38:56", scorer: "Mars",  isOpponent: true),
                GoalDetail(time: "39:26", scorer: "Hayko", assist: "Aro"),
                GoalDetail(time: "41:21", scorer: "Narek", assist: "Hayko"),
                GoalDetail(time: "49:13", scorer: "Mars",  isOpponent: true),
             ],
             mediaLinks: [
                MediaLink(title: "Full Match", urlString: "https://www.youtube.com/watch?v=Tx2OUyYEzCg&t=2767s", type: .video),
             ]),
        Game(date: date(2025,3,29), opponent: "Real-Synopsis", goalsFor: 2, goalsAgainst: 1,
             scorers: ["Aro","Garo"],
             goalDetails: [
                GoalDetail(time: "20:20", scorer: "Aro",      assist: "Narek"),
                GoalDetail(time: "37:24", scorer: "Garo",     assist: "Hayko"),
                GoalDetail(time: "40:53", scorer: "Synopsis", isOpponent: true),
             ],
             mediaLinks: [
                MediaLink(title: "Full Match", urlString: "https://www.youtube.com/watch?v=38mc7N2Ov8g&t=486s", type: .video),
             ]),
    ]
}
