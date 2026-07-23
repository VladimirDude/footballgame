import SwiftUI
import UIKit

enum PlayerPortraitStyle {
    case compact
    case game
    case hl
    case card
    case hero

    var size: CGFloat {
        switch self {
        case .compact: 56
        case .game: 80
        case .hl: 76
        case .card: 128
        case .hero: 128
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: 10
        case .game, .hl: 14
        case .card: 14
        case .hero: 14
        }
    }

    var placeholderIconSize: CGFloat {
        switch self {
        case .compact: 24
        case .game: 30
        case .hl: 36
        case .card: 44
        case .hero: 44
        }
    }
}

struct PlayerPortraitImage: View {
    let playerID: String
    var style: PlayerPortraitStyle = .compact

    @State private var image: UIImage?

    private var size: CGFloat { style.size }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                portraitPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay(portraitBorder)
        .shadow(
            color: .black.opacity(style == .compact ? 0.15 : (style == .game || style == .hl ? 0 : 0.22)),
            radius: style == .game || style == .hl ? 0 : (style == .compact ? 2 : 5),
            y: style == .game || style == .hl ? 0 : (style == .compact ? 1 : 2)
        )
        .task(id: playerID) { await loadImage() }
    }

    /// Loads the portrait off the main thread (decode + downsample) so scrolling
    /// never blocks on disk I/O. Cache hits resolve synchronously; misses decode
    /// on a background task and publish back on the main actor.
    private func loadImage() async {
        if let cached = PortraitStore.cachedImage(forID: playerID) {
            image = cached
            return
        }
        image = nil
        let id = playerID
        let maxPixel = size * 3
        let loaded = await Task.detached(priority: .userInitiated) {
            PortraitStore.loadImage(forID: id, maxPixel: maxPixel)
        }.value
        guard !Task.isCancelled else { return }
        image = loaded
    }

    @ViewBuilder
    private var portraitBorder: some View {
        switch style {
        case .game, .hl:
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        default:
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
        }
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
