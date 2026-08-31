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

    /// Caption for user-named entities group (spec 11a).
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
