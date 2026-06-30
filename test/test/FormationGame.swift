import Foundation

struct FormationPlayer: Identifiable {
    let id = UUID()
    let player: Player
}
func buildFormation(from players: [Player]) -> [FormationPlayer] {

    let attackers = players.filter { $0.position.contains("W") || $0.position.contains("F") }
    let mids = players.filter { $0.position.contains("M") }
    let defs = players.filter { $0.position.contains("D") }

    var formation: [FormationPlayer] = []

    formation += attackers.shuffled().prefix(2).map { FormationPlayer(player: $0) }
    formation += mids.shuffled().prefix(3).map { FormationPlayer(player: $0) }
    formation += defs.shuffled().prefix(4).map { FormationPlayer(player: $0) }

    return formation
}
