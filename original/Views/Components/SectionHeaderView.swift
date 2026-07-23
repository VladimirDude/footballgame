import SwiftUI

struct SectionHeaderView: View {
    let icon: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 4)
    }
}
