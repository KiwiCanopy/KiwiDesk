import KiwiDeskCore
import SwiftUI

/// The header's search entry (#678 turn 9): a field-shaped
/// button that opens the results popover, where the real field
/// and the result list live. A popover rather than an inline
/// dropdown because macOS gives it the key window for free —
/// the `AppPickerButton` precedent — where an overlay would
/// fight the header's siblings for hit-testing and focus.
///
/// ⌘K opens it from anywhere in the window; Escape closes it
/// (clearing first, matching `NSSearchField`, via the field's
/// own `onExitCommand`).
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

    @State private var open = false
    @State private var query = ""
    /// The ↑/↓ highlight, tracked by destination exactly as the
    /// sidebar's list selection did.
    @State private var highlighted: SettingsDestination?

    var body: some View {
        Button {
            open = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                Text(L("sidebar.search.placeholder", "Search"))
                Text("⌘K")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("k", modifiers: .command)
        .accessibilityLabel(
            L("sidebar.search.placeholder", "Search")
        )
        .popover(isPresented: $open, arrowEdge: .bottom) {
            popoverContent
        }
        .onChange(of: open) { _, isOpen in
            if !isOpen {
                query = ""
                highlighted = nil
            }
        }
    }

    private var results: [SidebarSearchResult] {
        SidebarSearch.results(
            query: query,
            editingStoredProfile: editingStoredProfile
        )
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            SidebarSearchField(
                text: $query,
                focusOnAppear: true,
                onMove: move,
                onCommit: commitHighlighted
            )
            if !query.trimmed.isEmpty {
                resultList
            }
        }
        .padding(10)
        .frame(width: 320)
    }

    @ViewBuilder private var resultList: some View {
        let results = results
        if results.isEmpty {
            Text(L("sidebar.search.no_results", "No results"))
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
                        ? Color.accentColor.opacity(0.16)
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
        return L("sidebar.profiles.badge_ax", "start here")
    }

    private func pick(_ anchor: SettingsAnchor) {
        open = false
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
