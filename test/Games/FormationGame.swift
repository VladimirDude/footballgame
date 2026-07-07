import Foundation

struct FormationPlayer: Identifiable, Hashable {
    let id: String
    let player: GamePlayer
}

func buildFormation(from players: [GamePlayer]) -> [FormationPlayer] {
    
    // 1. Separate players by position group
    let attackers = players.filter { $0.club.contains("W") || $0.club.contains("F") } // Note: Update to $0.position if you add a position field later
    let mids = players.filter { $0.club.contains("M") }
    let defs = players.filter { $0.club.contains("D") }

    var formation: [FormationPlayer] = []

    // 2. Select players and build them with stable, persistent IDs
    formation += attackers.shuffled().prefix(2).map { player in
        FormationPlayer(id: "\(player.id)-ATK", player: player)
    }
    
    formation += mids.shuffled().prefix(3).map { player in
        FormationPlayer(id: "\(player.id)-MID", player: player)
    }
    
    formation += defs.shuffled().prefix(4).map { player in
        FormationPlayer(id: "\(player.id)-DEF", player: player)
    }

    return formation
}
