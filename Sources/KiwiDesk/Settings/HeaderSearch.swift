import KiwiDeskCore
import SwiftUI

/// Header search entry with inline results overlay (#678).
///
/// Collapses to glyph at narrow window widths (`SettingsWidthClass`).
/// Focusable via ⌘K.
struct HeaderSearch: View {
    /// Whether collapsed entry is expanded.
    @Binding var expanded: Bool
    let context: SettingsSearchContext
    /// Profiles spotlight badge state — passed through so which
    /// list renders the tile does not change it.
    let spotlightProfiles: Bool
    /// A census key's current value, from the draft in memory —
    /// evaluated per rendered row, after the list paints.
    let value: (SettingKey) -> String?
    /// Hands a pick up to the shell, which owns the destination
    /// and the scroll choreography.
    let reveal: (SettingsAnchor) -> Void

    @State var query = ""
    /// The one cursor pointer and keys share (`DropdownCursor`).
    @State var cursor = DropdownCursor<String>()
    @FocusState var focused: Bool
    @State var panelHovered = false
    /// What `SearchPanelWidth` sizes the results panel from.
    @State var panelRoom = SearchPanelRoom()
    @Environment(\.settingsWidth) private var width
    /// Where the card's glass stands down, its fallback takes the
    /// shadow the glass branch does without (#2399).
    @Environment(\.accessibilityReduceTransparency)
    var reduceTransparency

    var searching: Bool { !query.trimmed.isEmpty }

    /// The rows the keys move over; `SettingsSearch.results` is
    /// the one home of "nothing before a query" (#1470).
    var hits: [SettingsSearchResult] { results.flat }

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
        .frame(minWidth: 110, maxWidth: .infinity)
        .onGeometryChange(
            for: SearchPanelRoom.self,
            of: SearchPanelRoom.measured
        ) { panelRoom = $0 }
        .overlay(alignment: .topLeading) { resultPanel }
        .background { focusShortcut }
        .onChange(of: query) { _, _ in resetCursor() }
        // The narrow entry collapses once neither focus nor the
        // pointer holds the panel — a typed query's rows can be
        // hovered after the field blurs, and a blur alone raced
        // that hover-keepalive (#1030).
        .onChange(of: focused) { _, now in
            // A moved cursor does not outlive the focus that made
            // it, or the next focus re-opens with that row armed
            // for a bare Return (#1030).
            if !now { resetCursor() }
            collapseIfIdle()
        }
        .onChange(of: panelHovered) { _, _ in collapseIfIdle() }
    }

    private func collapseIfIdle() {
        if !focused, !panelHovered, !searching { expanded = false }
    }

    /// Collapsed magnifying glass button entry.
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

    /// Expands search and acquires focus asynchronously.
    private func open() {
        expanded = true
        Task { @MainActor in focused = true }
    }

    /// ⌘K global shortcut button.
    private var focusShortcut: some View {
        Button("", action: open)
            .keyboardShortcut("k", modifiers: .command)
            // Reached by its chord, never Tab (#2584).
            .focusable(false)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    /// Selects search result and reveals target anchor.
    func pick(_ result: SettingsSearchResult) {
        query = ""
        focused = false
        panelHovered = false
        expanded = false
        reveal(result.anchor)
    }

    /// The query's first match takes the cursor, the keyboard's.
    private func resetCursor() {
        cursor.reset(to: hits.first?.id, pointer: DropdownPointer.live())
    }

    /// Moves the cursor up or down the result list.
    private func move(_ direction: MoveCommandDirection) {
        let hits = hits
        guard !hits.isEmpty else { return }
        let step: Int
        switch direction {
        case .up: step = -1
        case .down: step = 1
        default: return
        }
        let id = cursor.keyMove(
            step,
            in: hits.map(\.id),
            pointer: DropdownPointer.live()
        )
        guard let hit = hits.first(where: { $0.id == id }) else { return }
        // Focus stays in the field, so VoiceOver hears the cursor
        // only if it is said.
        AccessibilityNotification.Announcement(
            SettingsSearchRow.title(of: hit)
        ).post()
    }

    /// Commits the highlighted result, or the first match of a
    /// TYPED query: a bare Return in an untouched field must not
    /// navigate somewhere the user did not name (#1030).
    private func commitHighlighted() {
        let hits = hits
        let picked = cursor.commit(
            in: hits.map(\.id),
            pointer: DropdownPointer.live()
        )
        let hit =
            hits.first { $0.id == picked }
            ?? (searching ? hits.first : nil)
        guard let hit else { return }
        pick(hit)
    }
}
