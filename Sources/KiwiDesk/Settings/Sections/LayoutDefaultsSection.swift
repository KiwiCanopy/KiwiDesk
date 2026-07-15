import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Layout Defaults (#68 §3.2): the global
/// per-mode placement tuning the Spaces rows' per-space
/// overrides deviate from, plus the minimum window size.
/// Splitting this out of Spaces keeps "define your spaces"
/// (short, daily-adjacent) separate from "tune how a mode
/// behaves" (occasional, denser). Gaps live in Appearance —
/// spacing is a visual, not placement logic (§3.14).
///
/// The modes are a small fixed set, one edited at a time, so a
/// per-mode tab strip replaces the former stacked scroll (#204):
/// the global minimum window size is pinned above the strip (it
/// feeds every mode), then one tab per mode shows only that
/// mode's editor. Floating has no tunables, so it has no tab.
struct LayoutDefaultsSection: View {
    @ObservedObject var model: SettingsModel
    @State private var selected: LayoutMode = .bsp
    @State private var didAutoSelect = false

    /// Tab order (#204) lives on `LayoutMode.placementTabs` —
    /// the sidebar search index renders the same list, so the
    /// curated order has exactly one home.
    private let modes = LayoutMode.placementTabs

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                minSizeSection
                // No `Divider()` (#275): every other top-level
                // pane separates sibling regions with the stack
                // spacing alone — a rule between top-level
                // regions exists nowhere else in the app. The
                // min-size card's own background already reads as
                // a region boundary, and the segmented strip
                // self-announces the pivot (Trackpad/Displays
                // precedent), so whitespace is the native + most
                // consistent break.
                tabStrip
                editor
            }
            .padding(16)
        }
        // Land on the profile's most-used mode the first time the
        // pane appears, then leave the user's tab choice alone
        // (mirrors `ShortcutsSection.ensureSelection`).
        .onAppear {
            guard !didAutoSelect else { return }
            selected = initialMode
            didAutoSelect = true
        }
    }

    private var tabStrip: some View {
        SegmentedPicker(
            selection: $selected,
            options: modes.map { ($0.displayName, $0) }
        )
        .accessibilityLabel(
            L("layout_defaults.mode_tabs", "Layout mode")
        )
    }

    @ViewBuilder
    private var editor: some View {
        switch selected {
        case .bsp: BspEditor(model: model)
        case .stack: StackEditor(model: model)
        case .scrolling: ScrollingEditor(model: model)
        case .grid: GridEditor(model: model)
        case .monocle: MonocleEditor(model: model)
        case .track: TrackEditor(model: model)
        case .floating: EmptyView()
        }
    }

    /// The most common mode across the profile's spaces, falling
    /// back to BSP — so a user who lives in one mode lands on its
    /// tab. Floating (no tunables) never wins; it has no tab.
    private var initialMode: LayoutMode {
        let counts = model.config.spaceModes.values
            .filter { modes.contains($0) }
            .reduce(into: [LayoutMode: Int]()) { $0[$1, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key ?? .bsp
    }

    private var minSizeSection: some View {
        SettingsSection(
            L(
                "layout_defaults.min_window_size",
                "Minimum window size"
            ),
            caption: L(
                "layout_defaults.min_window_size_caption",
                "Windows never tile smaller than this. It also "
                    + "sets the auto-size grid's cell size."
            )
        ) {
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
