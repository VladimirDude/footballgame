import SwiftUI
import UIKit

enum ClubLogoStyle {
    case compact
    case row
    case card
    case hero

    var size: CGFloat {
        switch self {
        case .compact: 28
        case .row: 36
        case .card: 48
        case .hero: 64
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: 7
        case .row: 9
        case .card: 12
        case .hero: 14
        }
    }

    /// Inset between the crest artwork and the container edge.
    var contentInset: CGFloat {
        switch self {
        case .compact: 2
        case .row: 3
        case .card: 4
        case .hero: 5
        }
    }

    var placeholderIconSize: CGFloat {
        switch self {
        case .compact: 12
        case .row: 16
        case .card: 20
        case .hero: 28
        }
    }
}

enum ClubLogoLoader {
    private static var imageCache: [String: UIImage] = [:]
    private static let lock = NSLock()

    static func resourceName(forClubID clubID: String) -> String {
        "club-\(clubID)"
    }

    static func bundledImage(forClubID clubID: String) -> UIImage? {
        if let cached = imageCache[clubID] {
            return cached
        }

        lock.lock()
        defer { lock.unlock() }

        if let cached = imageCache[clubID] {
            return cached
        }

        let resourceName = resourceName(forClubID: clubID)
        let candidates: [(String?, String)] = [
            ("Database/ClubLogos", resourceName),
            ("ClubLogos", resourceName),
            (nil, resourceName),
        ]

        for (subdirectory, name) in candidates {
            if let url = Bundle.main.url(
                forResource: name,
                withExtension: "png",
                subdirectory: subdirectory
            ), let image = UIImage(contentsOfFile: url.path) {
                imageCache[clubID] = image
                return image
            }
        }

        return nil
    }

    static func hasLogo(forClubID clubID: String) -> Bool {
        bundledImage(forClubID: clubID) != nil
    }
}

struct ClubLogoImage: View {
    let clubID: String?
    var clubName: String = ""
    var style: ClubLogoStyle = .compact

    private var size: CGFloat { style.size }
    private var artworkSize: CGFloat { max(12, size - style.contentInset * 2) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(Color.white)

            if let clubID, let image = ClubLogoLoader.bundledImage(forClubID: clubID) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: artworkSize, height: artworkSize)
            } else {
                logoPlaceholder
            }
        }
        .frame(width: size, height: size)
        .fixedSize()
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
    }

    private var logoPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.42, blue: 0.24),
                    Color(red: 0.08, green: 0.3, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(placeholderLetter)
                .font(.system(size: style.placeholderIconSize + 4, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var placeholderLetter: String {
        let trimmed = clubName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}
