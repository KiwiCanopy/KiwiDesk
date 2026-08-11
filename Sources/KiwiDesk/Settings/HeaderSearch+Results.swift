import KiwiDeskCore
import SwiftUI

/// The header search's RESULT surface — the card hanging below
/// the field, its rows and the "Made by you" group's caption.
/// Split from `HeaderSearch` at the §2.1 ceiling when 17a's
/// collapsed entry landed: the field, its two entries and the
/// key handling are one job, and the panel below them another.
extension HeaderSearch {
    /// Hung below the field in the field's own coordinate
    /// space; the offset is the field's height plus the gap —
    /// a constant, since a `GeometryReader` around the FIELD
    /// would negotiate the flexible slot and collapse the row.
    ///
    /// 380 wide, a card under the field's leading edge — NOT
    /// the field's width. A full-width panel was tried against
    /// the line-through-the-panel report and rejected on sight
    /// once the real cause (the header separator's paint
    /// order) was fixed (owner, 2026-08-10). The responsive
    /// pass (17a) owns the final number.
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
                // 16b dark seam OVER the hairline: the black
                // shadow below is the panel's lift in light
                // and is invisible on the dark page — see
                // `SettingsTheme.planeRing`.
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
                // through an opaque panel (#758's lesson, hit
                // again here; owner report 2026-08-10).
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
            // Lazy on purpose: rows compute their value
            // enrichment when they appear, so a broad query
            // enriches the ~8 visible rows, never the whole set.
            // An overlay proposes the FIELD's size, and a
            // ScrollView adopts whatever it is proposed — so
            // without an explicit height the whole list
            // collapses to one clipped row (owner eyeball,
            // 2026-08-10). The height is the content's own
            // estimate, capped; past the cap it scrolls.
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

    /// Estimated content height: two-line rows at ~40 pt, the
    /// group caption when present, capped at 320 (the shipped
    /// max) — an estimate is safe because past the cap the list
    /// scrolls and under it a few points of slack vanish into
    /// the padding.
    func panelHeight(
        _ results: SettingsSearchResults
    ) -> CGFloat {
        let rows = CGFloat(results.flat.count)
        let header: CGFloat = results.places.isEmpty ? 0 : 26
        return min(rows * 40 + header, 320)
    }

    /// The group's caption (spec 11a): the user's own named
    /// things, below the settings rows.
    ///
    /// Named by OWNERSHIP, not by location. A location word is a
    /// metaphor only English carries here — the group holds a
    /// Space, a Profile and an App rule — and the literal
    /// translation collided outright in two catalogs: fr
    /// "Emplacements" is already the tiling slot, zh 位置 is
    /// already the "Position" setting label on rows this very
    /// search indexes. "Item" was unavailable to translate into:
    /// it is a ruled noun for a bar entry
    /// (.claude/rules/config-vocabulary.md), and its Romance
    /// renderings collide the same way. The wire keeps `place` —
    /// in code the thing is a jump target.
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
        // The list convention: no fill at rest, a quiet wash
        // under the pointer (owner, 2026-08-10: rows read
        // inert without it).
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

    /// The spotlight dot's VoiceOver twin — empty when unbadged
    /// (the sidebar's rule, carried whole).
    func badgeValue(
        for destination: SettingsDestination
    ) -> String {
        guard spotlightProfiles, destination == .profiles
        else { return "" }
        return L("home.profiles.badge_ax", "start here")
    }
}
