import KiwiDeskCore
import SwiftUI

/// Layout Defaults, rendered from the settings census (#678
/// Phase 3, turn 10): how each layout behaves before any space
/// overrides it.
///
/// Thirty-six rows live here, and nobody ever wants more than
/// one layout's worth. So the page is a **strip of live layout
/// thumbnails** — not a tab strip of words — and picking one
/// swaps the whole body: only the selected layout's rows are
/// ever mounted, so the most anyone sees is eight.
///
/// The minimum window size sits ABOVE the strip because it
/// governs all seven and silently caps auto-sized grids and
/// track limits; inside a layout's card it would read as that
/// layout's setting. Anything shared by every layout belongs
/// above the selector.
///
/// Gaps live in Gaps & Borders — spacing is a visual, not
/// placement logic (§3.14).
struct LayoutDefaultsSection: View {
    @ObservedObject var model: SettingsModel

    /// The selected layout, on the model rather than in `@State`
    /// (#277): a search hit on a layout-scoped control has to
    /// select that layout before there is anything to scroll to,
    /// and view-local state cannot be written from outside. `nil`
    /// still means "the user has not picked yet", so the
    /// most-used-layout landing below survives.
    private var selected: Binding<LayoutMode> {
        Binding(
            get: { model.nav.layoutModeTab ?? initialMode },
            set: { model.nav.layoutModeTab = $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                minSizeSection
                LayoutStrip(model: model, selection: selected)
                LayoutCard(
                    model: model,
                    mode: selected.wrappedValue
                )
                LayoutPreviewPanel(
                    model: model,
                    mode: selected.wrappedValue
                )
                SpacesUsingLayout(
                    model: model,
                    mode: selected.wrappedValue
                )
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
        // Land on the profile's most-used layout, then leave the
        // selection alone (mirrors
        // `ShortcutsSection.ensureSelection`). Latched by writing
        // the model once rather than by a separate flag: without
        // the write, `selected` would keep re-deriving
        // `initialMode`, so adding a space in another area could
        // move this one under the user.
        //
        // The latch is cleared by
        // `SettingsNavigation.resetSurfaces()` — on window open
        // and on an edit-target switch — so this still re-derives
        // per visit in the cases that matter, which is what it did
        // as view-local `@State`.
        .onAppear {
            if model.nav.layoutModeTab == nil {
                model.nav.layoutModeTab = initialMode
            }
        }
    }

    /// The most common layout across the profile's spaces,
    /// falling back to BSP — so a user who lives in one layout
    /// lands on it. Floating (no tunables) never wins; it has no
    /// tile.
    private var initialMode: LayoutMode {
        let tabs = LayoutMode.placementTabs
        let counts = model.config.spaceModes.values
            .filter { tabs.contains($0) }
            .reduce(into: [LayoutMode: Int]()) { $0[$1, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key ?? .bsp
    }

    /// The one row above the strip. Rendered through the same
    /// order list as every other row here, so it is census-owned
    /// too — its container is `.general`, which is what "shared
    /// by every layout" looks like in the census.
    private var minSizeSection: some View {
        SettingsSection(
            SettingsCatalog.layoutDefaults.minWindowSize,
            caption: L(
                "layout_defaults.min_window_size_caption",
                "Windows never tile smaller than this — it also "
                    + "caps auto-sized grids and track limits."
            )
        ) {
            ForEach(LayoutDefaultsRowOrder.general, id: \.id) {
                key in
                generalRow(key)
            }
        }
    }

    @ViewBuilder
    private func generalRow(_ key: SettingKey) -> some View {
        switch key {
        case .behaviour(.minWindowSize):
            // Label hidden (#275): the section header already
            // names this sole control, so the row shows value +
            // unit only (Dock "Size" pattern). `label` still
            // carries the accessibility name.
            StepperRow(
                label: L(
                    "layout_defaults.min_window_size",
                    "Minimum window size"
                ),
                value: minSizeBinding,
                in: 100...800,
                step: 10,
                suffix: "pt",
                labelHidden: true
            )
        default:
            let _ = assertionFailure(
                "unrendered Layout Defaults general row: \(key.id)"
            )
            EmptyView()
        }
    }

    /// `minWindowSize` is a `CGFloat`; the shared `StepperRow`
    /// edits an `Int`, so bridge through a whole-pt binding
    /// (it steps by 10, so no sub-pt precision is lost).
    private var minSizeBinding: Binding<Int> {
        Binding(
            get: { Int(model.config.settings.minWindowSize) },
            set: {
                model.config.settings.minWindowSize = CGFloat($0)
            }
        )
    }
}
