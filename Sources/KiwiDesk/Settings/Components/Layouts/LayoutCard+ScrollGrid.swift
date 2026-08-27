import KiwiDeskCore
import SwiftUI

/// The Scrolling and Grid row builders (see `LayoutCard+Rows`
/// for the dispatch and the shared bindings).
extension LayoutCard {
    /// The scroll axis runs top↔bottom when vertical, so the slot
    /// size reads as a row *height* and the anchor ends as
    /// top/bottom — labels swap accordingly (frontend only; the
    /// stored `slot_size` and anchor enum are
    /// orientation-neutral).
    var isVertical: Bool {
        model.config.settings.scrolling.orientation == .vertical
    }

    // MARK: - Scrolling

    var scrollOrientationRow: some View {
        SegmentedPicker(
            L(
                "scroll_grid.scroll_orientation",
                "Scroll orientation"
            ),
            selection: scrolling.orientation,
            options: [
                (
                    L("scroll_grid.horizontal", "Horizontal"),
                    ScrollingParams.Orientation.horizontal
                ),
                (L("scroll_grid.vertical", "Vertical"), .vertical),
            ]
        )
    }

    /// Every anchor the enum declares, labelled by
    /// `ScrollAnchorLabel` — which owns the axis-relative
    /// Top/Left branch and is shared with the per-space override
    /// row, so a fifth anchor appears in both without an edit
    /// here.
    var scrollAnchorRow: some View {
        SegmentedPicker(
            L("scroll_grid.focus_anchor", "Focus anchor"),
            selection: scrolling.anchor,
            options: anchorOptions
        )
    }

    private var anchorOptions: [(title: String, value: ScrollingParams.Anchor)]
    {
        ScrollingParams.Anchor.allCases.map {
            (
                title: ScrollAnchorLabel.text(
                    for: $0,
                    isVertical: isVertical
                ),
                value: $0
            )
        }
    }

    var slotSizeUnitRow: some View {
        SlotSizeRows(
            model: model,
            size: scrolling.slotSize,
            isVertical: isVertical,
            part: .unit
        )
    }

    var slotSizeValueRow: some View {
        SlotSizeRows(
            model: model,
            size: scrolling.slotSize,
            isVertical: isVertical,
            part: .control
        )
    }

    var scrollWrapFocusRow: some View {
        ToggleRow(
            label: L("scroll_grid.wrap_focus", "Wrap focus"),
            isOn: scrolling.wrapFocus,
            help: LayoutHelp.wrapFocus
        )
    }

    /// The scrolling-specific animation pair (#68 §3.5): the
    /// on/off switch and its magnitude sit together, and the
    /// census places both in this area rather than in Colours &
    /// Animations — a scroll's timing is the scroll's, not the
    /// app's.
    var animateFocusShiftsRow: some View {
        ToggleRow(
            label: L(
                "scroll_grid.animate_focus_shifts",
                "Animate focus shifts"
            ),
            isOn: $model.config.settings.animations.onScrolling,
            help: LayoutHelp.animateFocusShifts
        )
    }

    var scrollDurationRow: some View {
        StepperRow(
            label: L(
                "scroll_grid.scroll_duration",
                "Scroll duration"
            ),
            value: $model.config.settings.animations
                .scrollDurationMS,
            in: 50...1000,
            step: 10,
            suffix: "ms"
        )
    }

    // MARK: - Grid

    var gridTypeRow: some View {
        SegmentedPicker(
            L("scroll_grid.grid_type", "Grid type"),
            selection: grid.type,
            options: [
                (
                    L("scroll_grid.dynamic", "Dynamic"),
                    GridParams.GridType.dynamic
                ),
                (L("scroll_grid.rigid", "Rigid"), .rigid),
            ]
        )
    }

    /// "Arrange: Columns first / Rows first" (#217) — the GUI
    /// label only; the Lua/JSON `split_direction`
    /// (horizontal/vertical) wire vocabulary is unchanged. "Split
    /// direction" read ambiguously (divider-axis vs stack-axis
    /// camps); "Columns first / Rows first" names the window
    /// arrangement under both models.
    var gridArrangeRow: some View {
        SegmentedPicker(
            L("scroll_grid.arrange", "Arrange"),
            selection: grid.splitDirection,
            options: [
                (
                    L(
                        "scroll_grid.arrange.columns_first",
                        "Columns first"
                    ),
                    GridParams.SplitDirection.horizontal
                ),
                (
                    L(
                        "scroll_grid.arrange.rows_first",
                        "Rows first"
                    ), .vertical
                ),
            ]
        )
    }

    var gridFillEmptyRow: some View {
        ToggleRow(
            label: L(
                "scroll_grid.fill_empty_cells",
                "Fill empty cells"
            ),
            isOn: grid.fillEmptyCells
        )
    }

    /// The pair's shared verdict — asked once, so the grey and
    /// its sentence are one decision. Columns and Rows carry the
    /// same census gate, so either key answers for both.
    var gridDimensionsReason: LayoutDefaultsGates.InertReason? {
        gates.inertReason(for: .layout(.gridColumns))
    }

    /// The Auto-size toggle gating the Columns/Rows steppers, via
    /// the shared `AutoGatedGroup` (#233). A behaviour modifier
    /// like Fill empty cells — not a mode switch — so it reads as
    /// a plain toggle; on, it greys the steppers (visible but
    /// disabled, #171), the screen supplying the dimensions.
    ///
    /// The group's inertness comes from the resolver rather than
    /// from `isOn`, so the pair greys on exactly what the census
    /// says gates it — a space that overrides auto-size OFF keeps
    /// the global dimensions live (#520, #527).
    var gridDimensionsGroup: some View {
        AutoGatedGroup(
            title: L("scroll_grid.auto_size", "Auto-size grid"),
            isOn: grid.autoSize,
            caption: L(
                "scroll_grid.auto_size_caption",
                "Fits as many columns and rows as the screen "
                    + "allows, using the minimum window size above."
            ),
            gatedIsInert: gridDimensionsReason != nil,
            gatedHelp: gridDimensionsReason.map(
                LayoutDefaultsGateHelp.sentence
            ) ?? ""
        ) {
            StepperRow(
                label: L("scroll_grid.columns", "Columns"),
                value: grid.columns,
                in: 1...10
            )
            StepperRow(
                label: L("scroll_grid.rows", "Rows"),
                value: grid.rows,
                in: 1...10
            )
        }
    }
}
