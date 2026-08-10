import KiwiDeskCore
import SwiftUI

/// The header's search entry (#678 turn 9, rebuilt turn 16b;
/// per-setting results turn 11): the REAL field, inline in the
/// header, with its results hanging below it.
///
/// It shipped as a field-shaped *button* that opened a popover
/// holding the actual field — which was defensible while the
/// button was a small pill, and became a lie the moment the skin
/// made it look like the prototype's full-width field: clicking a
/// search field opened a second search field, and the one you
/// clicked could not be typed into (owner, 2026-08-04).
///
/// **The results are an overlay, not a popover, and that is
/// forced.** A popover takes the key window, so the header field
/// would lose focus on the first keystroke that produced a
/// result — the very reason the field originally lived *inside*
/// the popover. An overlay keeps focus where the user put it. The
/// cost is paint order: an overlay hanging past its parent's
/// bounds is drawn over by the next sibling in the shell's
/// `VStack`, so `SettingsView.chrome` lifts the header's
/// `zIndex`. Removing that lift hides the result list behind the
/// content.
///
/// ⌘K focuses it from anywhere in the window; Escape clears
/// (matching `NSSearchField`, via the field's own
/// `onExitCommand`), which is also what closes the list.
///
/// It is the header row's ONE flexible element: it takes every
/// point the chips beside it do not, which is what puts it in the
/// middle of the bar. The alternative — a fixed pill and a
/// `Spacer` — pushed the chips to the far edge and left a hole in
/// the middle of the header (owner, 2026-08-04).
struct HeaderSearch: View {
    /// Everything the result builder may read, collected by the
    /// header bar from state already in memory (the search path
    /// touches nothing else).
    let context: SettingsSearchContext
    /// The Profiles spotlight badge state, passed through to
    /// result rows so which list renders the tile does not
    /// change it.
    let spotlightProfiles: Bool
    /// Enrichment: the current value for a census key, from the
    /// draft in memory — evaluated per rendered row, after the
    /// list paints.
    let value: (SettingKey) -> String?
    /// Hands a picked result up to the shell, which owns the
    /// destination and the scroll choreography.
    let reveal: (SettingsAnchor) -> Void
    /// Arms the shell's one-line confirmation before a pick
    /// whose result predicts a mode flip — the reveal pipeline
    /// announces it only if the promotion actually happens
    /// (`SettingsView.apply`), so a refused reveal stays
    /// silent. Search's only mention of the mode.
    let armModeNotice: (SettingsDestination) -> Void

    @State private var query = ""
    /// The ↑/↓ highlight, by result id — a result set is
    /// per-setting now, so a destination no longer identifies a
    /// row.
    @State private var highlighted: String?
    @FocusState private var focused: Bool
    /// Keeps the panel alive while the pointer is INSIDE it:
    /// a row click lands outside the field's text editor, so
    /// `ClickAwayResignsFocus` resigns focus on the mouse-down
    /// — keyed on focus alone the row would vanish before its
    /// own mouse-up. A click anywhere else finds the pointer
    /// outside the panel and dismisses (owner, 2026-08-10:
    /// click-away left the list standing).
    @State private var panelHovered = false

    private var searching: Bool { !query.trimmed.isEmpty }

    var body: some View {
        SettingsSearchField(
            text: $query,
            focus: $focused,
            onMove: move,
            onCommit: commitHighlighted,
            shortcutHint: true
        )
        // The flexible slot. A floor as well as a ceiling: at the
        // 720 pt hard minimum the chips and the segment must not
        // squeeze the field down to its glyph.
        //
        // 110, not the 140 first tried: measured across the row
        // (back chip, profile chip, mode segment, plus the
        // 84 pt traffic-light inset — and, when it was
        // measured, the since-retired unsaved chip, so the
        // floor now runs with extra slack) 140 left the row
        // ~120 pt over the hard minimum, and a row that cannot
        // fit does not truncate politely — AppKit clips the
        // trailing element, which is a CONTROL. 17a's order is
        // preview, then rows, then chrome, and "controls
        // never".
        .frame(minWidth: 110, maxWidth: .infinity)
        .overlay(alignment: .topLeading) { resultPanel }
        .background { focusShortcut }
        // Typing moves the result set out from under the
        // highlight, so the highlight goes rather than pointing
        // at whatever now sits in that row.
        .onChange(of: query) { _, _ in highlighted = nil }
    }

    /// ⌘K, as a zero-size button rather than on the field: a
    /// `keyboardShortcut` on a `TextField` competes with the
    /// field's own key handling, and this needs to fire while
    /// focus is anywhere in the window.
    private var focusShortcut: some View {
        Button("") { focused = true }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

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
    @ViewBuilder private var resultPanel: some View {
        if searching, focused || panelHovered {
            resultCard
        }
    }

    private var resultCard: some View {
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

    private var results: SettingsSearchResults {
        SettingsSearch.results(query: query, context: context)
    }

    @ViewBuilder private var resultList: some View {
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
    private func panelHeight(
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
    private var placesHeader: some View {
        Text(L("search.places", "Made by you"))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(SettingsTheme.ink3)
            .padding(.horizontal, 8)
            .padding(.top, 6)
    }

    private func row(
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
    private func badgeValue(
        for destination: SettingsDestination
    ) -> String {
        guard spotlightProfiles, destination == .profiles
        else { return "" }
        return L("home.profiles.badge_ax", "start here")
    }

    /// Clearing the query is what dismisses the list — the panel
    /// is a function of `searching`, so there is no second piece
    /// of open/closed state to disagree with it.
    ///
    /// The mode question is answered BEFORE the reveal: the
    /// reveal path promotes the mode (`ensureModeAdmits`), so
    /// asking afterwards would always answer "no switch". The
    /// arm goes first — the reveal is what consumes it.
    private func pick(_ result: SettingsSearchResult) {
        if SettingsSearch.switchesMode(
            result,
            context: context
        ) {
            armModeNotice(result.destination)
        }
        query = ""
        highlighted = nil
        focused = false
        panelHovered = false
        reveal(result.anchor)
    }

    /// ↑/↓ from the field move the highlight only — the reveal
    /// (scroll and flash) waits for Return.
    private func move(_ direction: MoveCommandDirection) {
        let hits = results.flat
        guard !hits.isEmpty else { return }
        let current = hits.firstIndex { $0.id == highlighted }
        let next: Int
        switch direction {
        case .up:
            next = current.map { max($0 - 1, 0) } ?? 0
        case .down:
            next =
                current.map {
                    min($0 + 1, hits.count - 1)
                } ?? 0
        default:
            return
        }
        highlighted = hits[next].id
    }

    /// Falls back to the FIRST result: typing does not move the
    /// highlight, so after a fresh query a bare Return would
    /// otherwise be a dead key.
    private func commitHighlighted() {
        let hits = results.flat
        let hit =
            hits.first { $0.id == highlighted }
            ?? hits.first
        guard let hit else { return }
        pick(hit)
    }
}
