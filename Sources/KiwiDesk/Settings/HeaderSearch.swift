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
///
/// **Below the chrome breakpoint the field collapses to its own
/// glyph** (#678 turn 17a) — the LAST thing the shell gives up,
/// after the preview's column and the row axis, and the only one
/// that touches the header at all. It gives up nothing: the icon
/// opens the same field in the same slot, ⌘K still lands in it
/// from anywhere, and the area title yields for as long as it is
/// open. The alternative at 720 pt was the field's 110 pt floor
/// against a back chip, a profile chip and the mode segment,
/// which leaves the title nothing and clips whatever AppKit
/// reaches last — a CONTROL, which 17a's order forbids.
struct HeaderSearch: View {
    /// Whether the collapsed entry has been opened. Owned by the
    /// header bar, which is the view that has to yield the area
    /// title while the field is up — two views, one fact, so it
    /// cannot be `@State` here.
    @Binding var expanded: Bool
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

    @State var query = ""
    /// The ↑/↓ highlight, by result id — a result set is
    /// per-setting now, so a destination no longer identifies a
    /// row.
    @State var highlighted: String?
    @FocusState var focused: Bool
    /// Keeps the panel alive while the pointer is INSIDE it:
    /// a row click lands outside the field's text editor, so
    /// `ClickAwayResignsFocus` resigns focus on the mouse-down
    /// — keyed on focus alone the row would vanish before its
    /// own mouse-up. A click anywhere else finds the pointer
    /// outside the panel and dismisses (owner, 2026-08-10:
    /// click-away left the list standing).
    @State var panelHovered = false
    @Environment(\.settingsWidth) private var width

    var searching: Bool { !query.trimmed.isEmpty }

    /// The glyph stands in for the field only while the chrome
    /// is collapsed AND nobody has opened it.
    private var collapsed: Bool {
        width.collapsesChrome && !expanded
    }

    @ViewBuilder var body: some View {
        if collapsed {
            collapsedEntry
        } else {
            fieldEntry
        }
    }

    private var fieldEntry: some View {
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
        // An opened field that is done — focus gone, nothing
        // typed — hands the row back to the area title. Only
        // when it is EMPTY: a query is a result list the user
        // may still be reaching for with the mouse.
        .onChange(of: focused) { _, now in
            if !now, !searching { expanded = false }
        }
    }

    /// The collapsed entry: the field's own glyph, in the field's
    /// own slot, still the row's flexible element — the `Spacer`
    /// is what keeps the chips clustered at the trailing edge
    /// once the field stops filling the middle.
    private var collapsedEntry: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button(action: open) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SettingsTheme.ink2)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .iconButtonAffordance(
                L("search.placeholder", "Search")
            )
            .background { focusShortcut }
        }
    }

    /// Opening is one act: the field appears AND takes focus.
    /// Two clicks to type would make the glyph a worse field
    /// than the one it replaced.
    private func open() {
        expanded = true
        focused = true
    }

    /// ⌘K, as a zero-size button rather than on the field: a
    /// `keyboardShortcut` on a `TextField` competes with the
    /// field's own key handling, and this needs to fire while
    /// focus is anywhere in the window. Mounted in BOTH entries,
    /// so the shortcut opens the collapsed one rather than
    /// focusing a field that is not on screen.
    private var focusShortcut: some View {
        Button("", action: open)
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    /// Clearing the query is what dismisses the list — the panel
    /// is a function of `searching`, so there is no second piece
    /// of open/closed state to disagree with it.
    ///
    /// The mode question is answered BEFORE the reveal: the
    /// reveal path promotes the mode (`ensureModeAdmits`), so
    /// asking afterwards would always answer "no switch". The
    /// arm goes first — the reveal is what consumes it.
    func pick(_ result: SettingsSearchResult) {
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
        // A picked result is a navigation, and the screen it
        // lands on wants its title back — the collapsed entry's
        // whole reason for existing.
        expanded = false
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
