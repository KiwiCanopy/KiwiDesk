import KiwiDeskCore
import SwiftUI

/// Header search result dropdown presentation and layout.
extension HeaderSearch {
    /// Search results popup card attached below search field
    /// (owner 2026-08-10).
    /// Only with a query: a panel with rows before one popped
    /// over Home on every open, since the field takes the
    /// window's arrival focus (#1468, retired in #1470).
    @ViewBuilder var resultPanel: some View {
        if focused || panelHovered, searching {
            resultCard
        }
    }

    /// SPIKE (#2399): the card on Liquid Glass, `.regular` and
    /// untinted (#1295), today's card fill as the fallback. The
    /// rings draw on both branches; the shadow only where glass
    /// cannot draw, since a composited glass loses its backdrop.
    var resultCard: some View {
        let shape = RoundedRectangle(
            cornerRadius: SettingsTheme.cardRadius
        )
        return
            resultList
            .padding(8)
            .frame(
                width: SearchPanelWidth.width(for: panelRoom),
                alignment: .leading
            )
            .tint(SettingsTheme.accent)
            .glassChrome(
                in: shape,
                enabled: true,
                variant: .regular,
                fallback: AnyShapeStyle(SettingsTheme.card)
            )
            .overlay(shape.strokeBorder(SettingsTheme.hairline))
            .overlay(
                shape.strokeBorder(SettingsTheme.planeRing, lineWidth: 1)
            )
            .background {
                if !GlassChromeVariant.drawable {
                    // #758: composited, or the rings halo inward.
                    shape.fill(SettingsTheme.card)
                        .compositingGroup()
                        .shadow(
                            color: .black.opacity(0.16),
                            radius: 12,
                            y: 4
                        )
                }
            }
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
        let onCursor = result.id == cursor.highlighted
        return SettingsSearchRow(
            result: result,
            onCursor: onCursor,
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
        .dropdownCursorRow(onCursor) {
            cursor.hover(result.id, pointer: DropdownPointer.live())
        }
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
