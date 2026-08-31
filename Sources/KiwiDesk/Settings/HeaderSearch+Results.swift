import KiwiDeskCore
import SwiftUI

/// Header search result dropdown presentation and layout.
extension HeaderSearch {
    /// Search results popup card attached below search field
    /// (owner 2026-08-10).
    @ViewBuilder var resultPanel: some View {
        if searching, focused || panelHovered {
            resultCard
        }
    }

    var resultCard: some View {
        resultList
            .padding(8)
            .frame(width: 380, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
                .fill(SettingsTheme.card)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: SettingsTheme.cardRadius
                    )
                    .strokeBorder(SettingsTheme.hairline)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: SettingsTheme.cardRadius
                    )
                    .strokeBorder(
                        SettingsTheme.planeRing,
                        lineWidth: 1
                    )
                )
                // Without this the shadow halos EVERY
                // primitive — the hairline ring casts its own
                // shadow INWARD, reading as a line ghosting
                // through the panel (#758's lesson, hit again;
                // owner report 2026-08-10).
                .compositingGroup()
                .shadow(
                    color: .black.opacity(0.16),
                    radius: 12,
                    y: 4
                )
            )
            .offset(y: 40)
            .onHover { panelHovered = $0 }
    }

    var results: SettingsSearchResults {
        SettingsSearch.results(query: query, context: context)
    }

    @ViewBuilder var resultList: some View {
        let results = results
        if results.isEmpty {
            Text(L("search.no_results", "No results"))
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            // Lazy on purpose: rows enrich on appear, so a
            // broad query enriches ~8 visible rows, never the set.
            // An overlay proposes the FIELD's size and a
            // ScrollView adopts what it is proposed — without an
            // explicit height the list collapses to one clipped
            // row (owner eyeball, 2026-08-10).
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(results.settings) { result in
                        row(result)
                    }
                    if !results.places.isEmpty {
                        placesHeader
                        ForEach(results.places) { result in
                            row(result)
                        }
                    }
                }
            }
            .frame(height: panelHeight(results))
        }
    }

    /// Computes estimated height for dropdown scrollview.
    func panelHeight(
        _ results: SettingsSearchResults
    ) -> CGFloat {
        let rows = CGFloat(results.flat.count)
        let header: CGFloat = results.places.isEmpty ? 0 : 26
        return min(rows * 40 + header, 320)
    }

    /// Caption for user-named entities group (spec 11a). Named by
    /// OWNERSHIP, not location: the literal translation collided
    /// in two catalogs (fr "Emplacements" is the tiling slot, zh
    /// 位置 is the "Position" label), and "Item" is a ruled noun
    /// for a bar entry (config-vocabulary.md). The wire keeps
    /// `place`.
    var placesHeader: some View {
        Text(L("search.places", "Made by you"))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(SettingsTheme.ink3)
            .padding(.horizontal, 8)
            .padding(.top, 6)
    }

    func row(
        _ result: SettingsSearchResult
    ) -> some View {
        SettingsSearchRow(
            result: result,
            value: value,
            switchesMode: SettingsSearch.switchesMode(
                result,
                context: context
            ),
            badged: spotlightProfiles
                && result.destination == .profiles,
            badgeValue: badgeValue(for: result.destination),
            reveal: pick
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .rowHoverHighlight()
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    result.id == highlighted
                        ? SettingsTheme.accent.opacity(0.16)
                        : .clear
                )
        )
    }

    /// Accessibility description for profiles spotlight badge.
    func badgeValue(
        for destination: SettingsDestination
    ) -> String {
        guard spotlightProfiles, destination == .profiles
        else { return "" }
        return L("home.profiles.badge_ax", "start here")
    }
}
