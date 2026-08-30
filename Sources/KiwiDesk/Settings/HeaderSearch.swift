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
    /// Arms the shell's confirmation for a pick predicting a
    /// mode flip; the reveal pipeline announces it only if the
    /// promotion happens (`SettingsView.apply`), so a refused
    /// reveal stays silent. Search's only mention of the mode.
    let armModeNotice: (SettingsDestination) -> Void

    @State var query = ""
    @State var highlighted: String?
    @FocusState var focused: Bool
    @State var panelHovered = false
    @Environment(\.settingsWidth) private var width

    var searching: Bool { !query.trimmed.isEmpty }

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
        .overlay(alignment: .topLeading) { resultPanel }
        .background { focusShortcut }
        .onChange(of: query) { _, _ in highlighted = nil }
        .onChange(of: focused) { _, now in
            if !now, !searching { expanded = false }
        }
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
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    /// Selects search result and reveals target anchor.
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
        expanded = false
        reveal(result.anchor)
    }

    /// Moves highlight up or down in result list.
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

    /// Commits highlighted or first matching result.
    private func commitHighlighted() {
        let hits = results.flat
        let hit =
            hits.first { $0.id == highlighted }
            ?? hits.first
        guard let hit else { return }
        pick(hit)
    }
}
