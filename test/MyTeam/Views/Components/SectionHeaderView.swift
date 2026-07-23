import SwiftUI

struct SectionHeaderView: View {
    let icon: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TeamTheme.textPrimary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TeamTheme.textSecondary)
            }
        }
        .padding(.horizontal, 4)
    }
}
