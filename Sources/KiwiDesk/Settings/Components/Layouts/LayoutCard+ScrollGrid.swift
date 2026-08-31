import KiwiDeskCore
import SwiftUI

/// Scrolling and Grid layout settings row builders (`LayoutCard+Rows`).
extension LayoutCard {
    /// Indicates whether scrolling orientation is vertical.
    var isVertical: Bool {
        model.config.settings.scrolling.orientation == .vertical
    }

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

    /// Focus anchor segmented picker (`ScrollAnchorLabel`).
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

    /// Focus shift animation toggle for scrolling layout (#68 §3.5).
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

    /// Split direction arrange row ("Columns first / Rows first", #217).
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

    /// Shared inert reason for grid dimension controls.
    var gridDimensionsReason: LayoutDefaultsGates.InertReason? {
        gates.inertReason(for: .layout(.gridColumns))
    }

    /// Auto-sized grid group gating column/row steppers
    /// (`AutoGatedGroup`, #171, #233, #520, #527).
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
