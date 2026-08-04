import KiwiDeskCore
import SwiftUI

/// The header's search entry (#678 turn 9, rebuilt turn 16b):
/// the REAL field, inline in the header, with its results
/// hanging below it.
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
    /// The #18 axis the results filter on.
    let editingStoredProfile: Bool
    /// The Profiles spotlight badge state, passed through to
    /// result rows so which list renders the tile does not
    /// change it.
    let spotlightProfiles: Bool
    /// Hands a picked result up to the shell, which owns the
    /// destination and the scroll choreography.
    let reveal: (SettingsAnchor) -> Void

    @State private var query = ""
    /// The ↑/↓ highlight, tracked by destination exactly as the
    /// sidebar's list selection did.
    @State private var highlighted: SettingsDestination?
    @FocusState private var focused: Bool

    private var searching: Bool { !query.trimmed.isEmpty }

    var body: some View {
        SidebarSearchField(
            text: $query,
            focus: $focused,
            onMove: move,
            onCommit: commitHighlighted,
            shortcutHint: true
        )
        // The flexible slot. A floor as well as a ceiling: at the
        // 720 pt hard minimum the chips and the segment must not
        // squeeze the field down to its glyph.
        .frame(minWidth: 140, maxWidth: .infinity)
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

    /// Hung below the field in the field's own coordinate space.
    /// The offset is the field's height plus the gap; it is a
    /// constant because a `GeometryReader` here would hand the
    /// flexible slot a size to negotiate and collapse the row.
    @ViewBuilder private var resultPanel: some View {
        if searching {
            resultList
                .padding(8)
                .frame(width: 340, alignment: .leading)
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
                    .shadow(
                        color: .black.opacity(0.16),
                        radius: 12,
                        y: 4
                    )
                )
                .offset(y: 40)
        }
    }

    private var results: [SidebarSearchResult] {
        SidebarSearch.results(
            query: query,
            editingStoredProfile: editingStoredProfile
        )
    }

    @ViewBuilder private var resultList: some View {
        let results = results
        if results.isEmpty {
            Text(L("search.no_results", "No results"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(results) { result in
                        row(result)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }

    private func row(
        _ result: SidebarSearchResult
    ) -> some View {
        SidebarSearchRow(
            result: result,
            badged: spotlightProfiles
                && result.destination == .profiles,
            badgeValue: badgeValue(for: result.destination),
            reveal: pick
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    result.destination == highlighted
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
    private func pick(_ anchor: SettingsAnchor) {
        query = ""
        highlighted = nil
        focused = false
        reveal(anchor)
    }

    /// ↑/↓ from the field move the highlight only — the reveal
    /// (scroll and flash) waits for Return, as in the sidebar.
    private func move(_ direction: MoveCommandDirection) {
        let hits = results
        guard !hits.isEmpty else { return }
        let current = hits.firstIndex {
            $0.destination == highlighted
        }
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
        highlighted = hits[next].destination
    }

    /// Falls back to the FIRST result: typing does not move the
    /// highlight, so after a fresh query a bare Return would
    /// otherwise be a dead key.
    private func commitHighlighted() {
        let hits = results
        let hit =
            hits.first { $0.destination == highlighted }
            ?? hits.first
        guard let hit else { return }
        pick(hit.anchor)
    }
}
