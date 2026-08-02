import KiwiDeskCore
import SwiftUI

/// The two-group source list (#68 §3.1). Group headers name
/// the scope split (§0): "This Profile" follows the banner's
/// edit target, "Whole App" is always live state.
struct SettingsSidebar: View {
    /// The fixed column width (#297). Public to the module so
    /// `SidebarLabelWidthTests` can derive the label budget from
    /// it — narrowing the column must tighten the budget, not
    /// leave a guard enforcing a tolerance the column outgrew.
    static let columnWidth: CGFloat = 190
    /// What the column spends on everything that is not the
    /// label: the 8 pt card padding either side, the sidebar
    /// row's own insets, the 22 pt `SidebarTile` and its gap.
    /// `columnWidth - labelChrome` is the text budget.
    static let labelChrome: CGFloat = 70

    @Binding var selection: SettingsDestination
    /// Hides the global-only destinations while a stored
    /// profile is being edited (#18).
    let editingStoredProfile: Bool
    /// Accent dot on the Profiles tile while no profile exists
    /// yet (ui-designer 2026-07-19) — the Software Update
    /// "something to look at here" idiom, state-driven: gone
    /// the instant a profile exists, back if the last one is
    /// deleted. Never a gate.
    let spotlightProfiles: Bool
    /// Hands a picked search result up to the shell, which owns
    /// the destination, the surface switches and the scroll proxy
    /// (#277). The sidebar knows what was picked, not how to land
    /// on it.
    let reveal: (SettingsAnchor) -> Void
    /// Tones the inactive destination card; the identity mark no
    /// longer branches on appearance (#479).
    @Environment(\.colorScheme) private var colorScheme
    /// Solidifies the card wash while the window is inactive
    /// (#297) — per-element fades ride `InactiveDimmed` instead.
    @Environment(\.controlActiveState) private var activeState
    /// Subscribes the sidebar to live language changes: without
    /// it, section headers and row titles (`L(...)` /
    /// `destination.title`) only refresh when `selection` changes
    /// (a section switch), not on the language switch itself.
    @EnvironmentObject private var localization: LocalizationManager
    /// The live search query (#90). Typing only filters the
    /// list — `selection` changes on an explicit click alone —
    /// and the query survives navigation, so a user can try a
    /// hit, come back, and pick another (System Settings).
    @State private var query = ""

    var body: some View {
        List(selection: $selection) {
            if query.trimmed.isEmpty {
                groupedSections
            } else {
                searchResults
            }
        }
        .listStyle(.sidebar)
        // The shell is a plain `HStack`, not a split view (#297),
        // so the sidebar look is assembled by hand: hide the
        // list's own backdrop and put the source-list vibrancy
        // behind the whole column instead.
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                appIdentity
                SidebarSearchField(
                    text: $query,
                    onMove: move,
                    onCommit: commitHighlighted
                )
            }
        }
        // Fixed, non-resizable column (#297) — matching System
        // Settings. A closed ~9-row icon+label taxonomy never
        // needs more/less room, so a resize handle is the same
        // "bespoke panel" tell we killed the collapse toggle for
        // (#68).
        //
        // Re-measured across all ten locales when #95 landed: the
        // worst case is now `ru` "Сочетания клавиш" at ~118 pt,
        // up from de "Erscheinungsbild" at ~104 pt, and 190 pt
        // still clears it. Fifteen labels in eight locales did
        // *not* fit and were shortened instead of widening the
        // column — a sidebar destination wants a short noun (the
        // section header inside carries the full title), and
        // System Settings' own column does not grow per language.
        // Keep that the fix: a new locale whose destination label
        // measures past the text budget gets a shorter label, not
        // a wider sidebar. `SidebarLabelWidthTests` enforces it,
        // and derives the budget from `columnWidth` below rather
        // than restating a number this comment would have to keep
        // in step.
        .frame(width: Self.columnWidth)
        // Floating pane, the macOS 26 System Settings look: a
        // rounded translucent card in near-window-background
        // gray, carrying a soft shadow, with the traffic lights
        // inside its top edge (hence the ignored top safe area —
        // the card runs up under the titlebar strip).
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(8)
    }

    /// The floating card's surface, out of `body` (§5 shallow-
    /// body guardrail): vibrant material under a window-tone
    /// wash while active; flat gray while inactive — #F7F7F7,
    /// sampled straight from System Settings' inactive sidebar
    /// on macOS 26. Carries the card's drop shadow, so header
    /// text and tiles in the content subtree can't cast smudge
    /// shadows of their own.
    private var cardBackground: some View {
        ZStack {
            if activeState == .inactive {
                inactiveCardColor
            } else {
                SidebarMaterial()
                // Lift the material toward the window tone —
                // System Settings' pane is lighter than the
                // raw material. Adaptive, so it brightens
                // light mode and stays dark in dark.
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: .black.opacity(0.18),
            radius: 7,
            y: 2
        )
        .animation(InactiveDimmed.fade, value: activeState)
    }

    @ViewBuilder private var groupedSections: some View {
        Section(L("sidebar.section.design", "Design")) {
            ForEach(SettingsDestination.thisProfile) {
                row($0)
            }
        }
        Section(L("sidebar.section.system", "System")) {
            ForEach(visibleWholeApp) { row($0) }
        }
    }

    /// The live result list. A computed property, not a local in
    /// `searchResults`, because the keyboard handlers below step
    /// through the same list.
    private var results: [SidebarSearchResult] {
        SidebarSearch.results(
            query: query,
            editingStoredProfile: editingStoredProfile
        )
    }

    /// ↑/↓ from the field move the highlight and navigate, which
    /// is cheap; the scroll and flash wait for Return. Revealing
    /// on every keystroke would re-scroll and re-wash the pane
    /// while the user is still arrowing past it.
    private func move(_ direction: MoveCommandDirection) {
        let hits = results
        guard !hits.isEmpty else { return }
        // Arrowing during an in-flight reveal is deliberately NOT
        // cancelled from here: the shell owns that task, and
        // plumbing a third closure down would buy nothing. The
        // task bails on its own once the destination has moved
        // (it captures the one it was started for) — which closes
        // the case rather than resting on the id happening to be
        // absent from the new pane.
        let current = hits.firstIndex {
            $0.destination == selection
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
        selection = hits[next].destination
    }

    /// Falls back to the FIRST result, not to nothing: typing does
    /// not move `selection` (deliberate — see `query`), so after a
    /// fresh query nothing is highlighted yet and a bare Return
    /// would otherwise be a dead key until the user pressed an
    /// arrow. Every search UI reveals the top hit on Return.
    private func commitHighlighted() {
        let hit =
            results.first { $0.destination == selection }
            ?? results.first
        guard let hit else { return }
        reveal(hit.anchor)
    }

    /// The flat results list that replaces both groups while a
    /// query is live (#90): once a query narrows the sidebar, two
    /// mostly-empty scope headers are clutter. Rows stay
    /// selectable through the same `List(selection:)` identity.
    @ViewBuilder private var searchResults: some View {
        let results = results
        if results.isEmpty {
            Text(
                L("sidebar.search.no_results", "No results")
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        } else {
            ForEach(results) { result in
                SidebarSearchRow(
                    result: result,
                    badged: spotlightProfiles
                        && result.destination == .profiles,
                    badgeValue: axBadgeValue(
                        for: result.destination
                    ),
                    reveal: reveal
                )
            }
        }
    }

    /// App identity centered at the top of the sidebar (#68):
    /// colour mark + name, just under the traffic lights. The
    /// selected section's name rides the titlebar separately,
    /// the System Settings split.
    private var appIdentity: some View {
        HStack(spacing: 8) {
            if let mark {
                Image(nsImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            Text(L("sidebar.app_name", "KiwiDesk"))
                .font(.title3.weight(.semibold))
        }
        .inactiveDimmed()
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        // The card runs up under the titlebar, so the traffic
        // lights sit inside its top-left corner — the identity
        // row drops below them.
        .padding(.top, 34)
        .padding(.bottom, 8)
    }

    /// The flat inactive-card tone: #F7F7F7 is System
    /// Settings' exact inactive sidebar gray (sampled); dark
    /// mode has no sampled twin, so it falls back to the flat
    /// window background.
    private var inactiveCardColor: Color {
        colorScheme == .dark
            ? Color(nsColor: .windowBackgroundColor)
            : Color(
                red: 247 / 255,
                green: 247 / 255,
                blue: 247 / 255
            )
    }

    /// One mark in both appearances (#479): the symbol holds
    /// its kiwi green rather than re-hueing per theme, so there
    /// is nothing here to branch on.
    private var mark: NSImage? { BrandAssets.appMark }

    private var visibleWholeApp: [SettingsDestination] {
        SettingsDestination.wholeApp.filter {
            $0.isReachable(
                editingStoredProfile: editingStoredProfile
            )
        }
    }

    private func row(
        _ destination: SettingsDestination
    ) -> some View {
        Label {
            // Single-line insurance (#297): the column is now a
            // fixed 190pt, so an over-long translated label
            // truncates on one line instead of wrapping to two —
            // matching System Settings' single-line rows.
            Text(destination.title)
                .lineLimit(1)
        } icon: {
            SidebarTile(
                destination: destination,
                badged: spotlightProfiles
                    && destination == .profiles
            )
        }
        .tag(destination)
        .accessibilityValue(
            axBadgeValue(for: destination)
        )
    }

    /// The spotlight dot's VoiceOver twin (review 2026-07-19)
    /// — the visual badge alone would leave AX users without
    /// the sidebar-level cue. Empty when unbadged.
    func axBadgeValue(
        for destination: SettingsDestination
    ) -> String {
        guard spotlightProfiles, destination == .profiles
        else { return "" }
        return L(
            "sidebar.profiles.badge_ax",
            "start here"
        )
    }
}
