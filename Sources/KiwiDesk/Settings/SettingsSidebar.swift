import KiwiDeskCore
import SwiftUI

/// The two-group source list (#68 §3.1). Group headers name
/// the scope split (§0): "This Profile" follows the banner's
/// edit target, "Whole App" is always live state.
struct SettingsSidebar: View {
    @Binding var selection: SettingsDestination
    /// Hides the global-only destinations while a stored
    /// profile is being edited (#18).
    let editingStoredProfile: Bool
    /// Swaps the identity mark to the golden variant on dark.
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
                SidebarSearchField(text: $query)
            }
        }
        // Fixed, non-resizable column (#297) — matching System
        // Settings. A closed ~9-row icon+label taxonomy never
        // needs more/less room, so a resize handle is the same
        // "bespoke panel" tell we killed the collapse toggle for
        // (#68). Sized to clear the worst-case *translated* label
        // ("Erscheinungsbild"); revisit when the 8 languages land
        // (#95 / #135).
        .frame(width: 190)
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

    /// The flat results list that replaces both groups while a
    /// query is live (#90): once a query narrows the sidebar,
    /// two mostly-empty scope headers are clutter. Rows stay
    /// selectable through the same `List(selection:)` tags.
    @ViewBuilder private var searchResults: some View {
        let results = SidebarSearch.results(
            query: query,
            editingStoredProfile: editingStoredProfile
        )
        if results.isEmpty {
            Text(
                L("sidebar.search.no_results", "No results")
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        } else {
            ForEach(results) { resultRow($0) }
        }
    }

    private func resultRow(
        _ result: SidebarSearchResult
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(result.destination.title)
                if let subsection = result.subsection {
                    Text(subsection)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            SidebarTile(destination: result.destination)
        }
        .tag(result.destination)
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

    /// The golden dark mark on dark, colour mark on light;
    /// falls back across variants if one resource is missing.
    private var mark: NSImage? {
        colorScheme == .dark
            ? BrandAssets.appMarkDark ?? BrandAssets.appMark
            : BrandAssets.appMark
    }

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
            SidebarTile(destination: destination)
        }
        .tag(destination)
    }
}

/// A System-Settings-style icon tile: white glyph on a flat
/// rounded-rect color (§6.1).
struct SidebarTile: View {
    let destination: SettingsDestination

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(destination.tint)
            .frame(width: 22, height: 22)
            .overlay {
                Image(systemName: destination.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
            }
            // The soft lift System Settings gives its sidebar
            // icons — kept inside `inactiveDimmed` so the
            // shadow fades with the tile.
            .shadow(
                color: .black.opacity(0.25),
                radius: 1.5,
                y: 1
            )
            // The colored fill has no notion of window key
            // state; System Settings' tiles fade, hue kept
            // (#297).
            .inactiveDimmed()
    }
}
