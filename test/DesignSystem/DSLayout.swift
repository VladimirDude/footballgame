import SwiftUI

/// The one spacing scale for the whole app (previously only the Games layer had
/// one). Every margin/padding/gap should come from here.
enum DSSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
    static let huge: CGFloat = 48
    static let giant: CGFloat = 64
}

/// The one corner-radius scale (reconciles the 14 ad-hoc radii found in the app).
enum DSRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let pill: CGFloat = 999
}

/// Shadow/elevation tokens — the depth the flat, outline-only cards were missing.
enum DSElevation {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    static let sm = Shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    static let md = Shadow(color: .black.opacity(0.10), radius: 14, y: 6)
    static let lg = Shadow(color: .black.opacity(0.14), radius: 26, y: 12)
}

extension View {
    /// Applies an elevation shadow token.
    func dsElevation(_ shadow: DSElevation.Shadow = DSElevation.md) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }

    /// Wraps content in the canonical card surface: rounded, filled with
    /// `DSColor.surface`, hairline stroke, and a soft elevation shadow.
    func dsCard(
        radius: CGFloat = DSRadius.lg,
        padding: CGFloat = DSSpacing.md,
        elevation: DSElevation.Shadow = DSElevation.sm
    ) -> some View {
        self
            .padding(padding)
            .background(
                // Cast the shadow from the opaque background shape, NOT the whole
                // card. Applying `.shadow` to the composited content (incl. text)
                // forces an offscreen render pass per frame and janks scrolling;
                // shadowing just the filled rounded-rect is visually identical but
                // cheap.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DSColor.surface)
                    .shadow(color: elevation.color, radius: elevation.radius, x: 0, y: elevation.y)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(DSColor.separator, lineWidth: 0.5)
            )
    }
}
