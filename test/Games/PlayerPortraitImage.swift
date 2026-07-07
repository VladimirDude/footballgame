import SwiftUI
import UIKit

enum PlayerPortraitStyle {
    case compact
    case card
    case hero

    var size: CGFloat {
        switch self {
        case .compact: 56
        case .card: 128
        case .hero: 128
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: 10
        case .card: 14
        case .hero: 14
        }
    }

    var placeholderIconSize: CGFloat {
        switch self {
        case .compact: 24
        case .card: 44
        case .hero: 44
        }
    }
}

enum PlayerPortraitLoader {
    private static var imageCache: [String: UIImage] = [:]
    private static let lock = NSLock()

    static func bundledImage(forPlayerID playerID: String) -> UIImage? {
        if let cached = imageCache[playerID] {
            return cached
        }

        lock.lock()
        defer { lock.unlock() }

        if let cached = imageCache[playerID] {
            return cached
        }

        guard let fileURL = Bundle.main.url(forResource: playerID, withExtension: "png"),
              let image = UIImage(contentsOfFile: fileURL.path) else {
            return nil
        }

        imageCache[playerID] = image
        return image
    }
}

struct PlayerPortraitImage: View {
    let playerID: String
    var style: PlayerPortraitStyle = .compact

    private var size: CGFloat { style.size }

    var body: some View {
        Group {
            if let image = PlayerPortraitLoader.bundledImage(forPlayerID: playerID) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                portraitPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.2), radius: style == .compact ? 3 : 6, y: 2)
    }

    private var portraitPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.86, blue: 0.9),
                    Color(red: 0.68, green: 0.74, blue: 0.8),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "person.fill")
                .font(.system(size: style.placeholderIconSize, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }
}
