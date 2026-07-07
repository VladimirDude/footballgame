import Foundation

struct GuessPlayerRound: Identifiable {
    let id: String
    let playerName: String
    let position: String
    let clubName: String
    let nationalities: [String]
    let marketValue: Int

    var formattedMarketValue: String {
        MarketValueFormatter.format(marketValue)
    }
}
