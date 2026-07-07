import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var subtitle: String {
        switch self {
        case .system: "Match device settings"
        case .light: "Always light"
        case .dark: "Always dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AdaptiveLayout {
    static let browseMaxWidth: CGFloat = 900
    static let gameMaxWidth: CGFloat = 720
    static let settingsMaxWidth: CGFloat = 640
    static let detailMaxWidth: CGFloat = 760

    static func gridColumns(for sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        if sizeClass == .regular {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.flexible())]
    }
}

struct AdaptiveContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func adaptiveContentWidth(_ maxWidth: CGFloat = AdaptiveLayout.browseMaxWidth) -> some View {
        modifier(AdaptiveContentWidth(maxWidth: maxWidth))
    }
}
