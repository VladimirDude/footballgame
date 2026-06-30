import Foundation

struct Player: Identifiable {
    let id: String
    let name: String
    let club: String
    let position: String
    let marketValue: String
    let nationalities: [String]?

    var imageURL: String? {
        nil
    }
}
