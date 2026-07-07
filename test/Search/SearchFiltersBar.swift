import SwiftUI

struct SearchFiltersBar: View {
    @Binding var filters: PlayerSearchFilters

    let clubs: [ClubSummary]
    let leagues: [String]
    let nationalities: [String]

    @State private var showNationalityPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterMenu(
                        title: "Club",
                        selection: selectedClubName,
                        isActive: filters.clubID != nil
                    ) {
                        Button("Any Club") { filters.clubID = nil }
                        Divider()
                        ForEach(clubs) { club in
                            Button(club.name) { filters.clubID = club.id }
                        }
                    }

                    filterMenu(
                        title: "League",
                        selection: filters.league,
                        isActive: filters.league != nil
                    ) {
                        Button("Any League") { filters.league = nil }
                        Divider()
                        ForEach(leagues, id: \.self) { league in
                            Button(league) { filters.league = league }
                        }
                    }

                    filterMenu(
                        title: "Position",
                        selection: filters.positionGroup?.rawValue,
                        isActive: filters.positionGroup != nil
                    ) {
                        Button("Any Position") { filters.positionGroup = nil }
                        Divider()
                        ForEach(PositionGroup.allCases) { group in
                            Button(group.rawValue) { filters.positionGroup = group }
                        }
                    }

                    filterChip(
                        title: "Nation",
                        selection: filters.nationality,
                        isActive: filters.nationality != nil
                    ) {
                        showNationalityPicker = true
                    }

                    if filters.isActive {
                        Button {
                            filters.clear()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color(.tertiarySystemGroupedBackground)))
                        }
                    }
                }
                .padding(.horizontal)
            }

            if filters.isActive {
                Text(activeFilterSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showNationalityPicker) {
            NationalityPickerSheet(
                nationalities: nationalities,
                selection: $filters.nationality
            )
        }
    }

    private var selectedClubName: String? {
        guard let clubID = filters.clubID else { return nil }
        return clubs.first { $0.id == clubID }?.name
    }

    private var activeFilterSummary: String {
        var parts: [String] = []
        if let name = selectedClubName { parts.append(name) }
        if let league = filters.league { parts.append(league) }
        if let group = filters.positionGroup { parts.append(group.rawValue) }
        if let nation = filters.nationality { parts.append(nation) }
        return parts.joined(separator: " · ")
    }

    private func filterMenu<Content: View>(
        title: String,
        selection: String?,
        isActive: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            filterChipLabel(title: title, selection: selection, isActive: isActive)
        }
    }

    private func filterChip(
        title: String,
        selection: String?,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            filterChipLabel(title: title, selection: selection, isActive: isActive)
        }
        .buttonStyle(.plain)
    }

    private func filterChipLabel(title: String, selection: String?, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Text(selection ?? title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isActive ? BrowseTheme.accent : Color(.tertiarySystemGroupedBackground))
        )
    }
}

private struct NationalityPickerSheet: View {
    let nationalities: [String]
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nationalities }
        let needle = trimmed.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return nationalities.filter {
            $0.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Button("Any Nationality") {
                    selection = nil
                    dismiss()
                }

                ForEach(filtered, id: \.self) { nationality in
                    Button {
                        selection = nationality
                        dismiss()
                    } label: {
                        HStack {
                            Text(CountryFlags.flag(for: nationality))
                            Text(nationality)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selection == nationality {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(BrowseTheme.accent)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search nationality")
            .navigationTitle("Nationality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
