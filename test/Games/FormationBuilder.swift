import Foundation

enum FormationBuilder {

    /// Builds an attacking 4-3-3 from a full squad, showing primary nationality flags per slot.
    static func build(from squad: [ClubSquadPlayer]) -> [[FormationSlot]] {
        var pool = squad.sorted { ($0.marketValue ?? 0) > ($1.marketValue ?? 0) }

        // Added an optional positionKey parameter to keep the id unique while keeping the role clean
        func take(where matches: (ClubSquadPlayer) -> Bool, role: String, positionKey: String? = nil) -> FormationSlot? {
            guard let index = pool.firstIndex(where: matches) else { return nil }
            let player = pool.remove(at: index)
            
            // The ID stays completely unique, but the role displayed remains clean ("CM" or "CB")
            let stableId = "\(player.name)-\(positionKey ?? role)"
            
            return FormationSlot(
                id: stableId,
                role: role,
                flag: CountryFlags.primaryFlag(from: player.nationality),
                playerName: player.name
            )
        }

        let attack = [
            take(where: { isLeftWinger($0.position) }, role: "LW"),
            take(where: { isStriker($0.position) }, role: "ST"),
            take(where: { isRightWinger($0.position) }, role: "RW"),
        ].compactMap { $0 }

        // Roles are kept strictly as "CM", but tracked uniquely via positionKey parameters
        let midfield = [
            take(where: { isMidfielder($0.position) }, role: "CM", positionKey: "CM-Left"),
            take(where: { isMidfielder($0.position) }, role: "CM", positionKey: "CM-Center"),
            take(where: { isMidfielder($0.position) }, role: "CM", positionKey: "CM-Right"),
        ].compactMap { $0 }

        // Roles are kept strictly as "CB"
        let defense = [
            take(where: { isLeftBack($0.position) }, role: "LB"),
            take(where: { isCentreBack($0.position) }, role: "CB", positionKey: "CB-Left"),
            take(where: { isCentreBack($0.position) }, role: "CB", positionKey: "CB-Right"),
            take(where: { isRightBack($0.position) }, role: "RB"),
        ].compactMap { $0 }

        let goalkeeper = [
            take(where: { isGoalkeeper($0.position) }, role: "GK"),
        ].compactMap { $0 }

        var lines = [attack, midfield, defense, goalkeeper]
        fillMissingSlots(in: &lines, from: &pool)
        return lines.filter { !$0.isEmpty }
    }

    private static func fillMissingSlots(in lines: inout [[FormationSlot]], from pool: inout [ClubSquadPlayer]) {
        let targetCounts = [3, 3, 4, 1]
        let defaultRoles = [
            ["LW", "ST", "RW"],
            ["CM", "CM", "CM"], // Clean UI display values
            ["LB", "CB", "CB", "RB"], // Clean UI display values
            ["GK"],
        ]
        let positionKeys = [
            ["LW", "ST", "RW"],
            ["CM-Left", "CM-Center", "CM-Right"], // Behind-the-scenes unique tracking IDs
            ["LB", "CB-Left", "CB-Right", "RB"],
            ["GK"],
        ]

        for row in 0..<min(lines.count, targetCounts.count) {
            while lines[row].count < targetCounts[row], let player = pool.first {
                pool.removeFirst()
                let role = defaultRoles[row][lines[row].count]
                let posKey = positionKeys[row][lines[row].count]
                let stableId = "\(player.name)-\(posKey)"
                
                lines[row].append(
                    FormationSlot(
                        id: stableId,
                        role: role,
                        flag: CountryFlags.primaryFlag(from: player.nationality),
                        playerName: player.name
                    )
                )
            }
        }
    }

    private static func isGoalkeeper(_ position: String) -> Bool {
        position.localizedCaseInsensitiveContains("goalkeeper")
    }

    private static func isCentreBack(_ position: String) -> Bool {
        position.localizedCaseInsensitiveContains("centre-back")
            || position.localizedCaseInsensitiveContains("center-back")
    }

    private static func isLeftBack(_ position: String) -> Bool {
        position.localizedCaseInsensitiveContains("left-back")
    }

    private static func isRightBack(_ position: String) -> Bool {
        position.localizedCaseInsensitiveContains("right-back")
    }

    private static func isMidfielder(_ position: String) -> Bool {
        let p = position.lowercased()
        return p.contains("midfield") || p.contains("midfielder")
    }

    private static func isLeftWinger(_ position: String) -> Bool {
        let p = position.lowercased()
        return p.contains("left winger") || p.contains("left midfield")
    }

    private static func isRightWinger(_ position: String) -> Bool {
        let p = position.lowercased()
        return p.contains("right winger") || p.contains("right midfield")
    }

    private static func isStriker(_ position: String) -> Bool {
        let p = position.lowercased()
        return p.contains("centre-forward")
            || p.contains("center-forward")
            || p.contains("second striker")
            || p.contains("striker")
    }
}
