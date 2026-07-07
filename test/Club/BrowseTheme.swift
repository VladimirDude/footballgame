import SwiftUI

enum BrowseTheme {
    static let pitchTop = Color(red: 0.1, green: 0.55, blue: 0.2)
    static let pitchBottom = Color(red: 0.05, green: 0.4, blue: 0.15)
    static let accent = Color.orange

    static var pitchGradient: LinearGradient {
        LinearGradient(
            colors: [pitchTop, pitchBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BrowseCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Color(.secondarySystemGroupedBackground))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color.primary.opacity(0.06), lineWidth: 1)
      )
  }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = BrowseTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(tint)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(BrowseTheme.accent)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}
