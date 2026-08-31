import KiwiDeskCore
import SwiftUI

/// Layout Defaults row builders for BSP, Stack, and Monocle settings
/// (`LayoutCard`).
extension LayoutCard {
    @ViewBuilder func layoutRow(_ key: LayoutKey) -> some View {
        switch key {
        case .bspStrategy: bspStrategyRow
        case .bspSplitRatioH: bspRatioHRow
        case .bspSplitRatioV: bspRatioVRow
        case .stackMasterCount: masterCountRow
        case .stackMasterRatio: masterRatioRow
        case .stackMasterOrientation: masterOrientationRow
        case .stackStackPosition: stackPositionRow
        case .stackOverflowStyle: stackOverflowRow
        case .scrollingOrientation: scrollOrientationRow
        case .scrollingAnchor: scrollAnchorRow
        case .scrollingSlotSizeUnit: slotSizeUnitRow
        case .scrollingSlotSizeValue: slotSizeValueRow
        case .scrollingWrapFocus: scrollWrapFocusRow
        case .gridType: gridTypeRow
        case .gridSplitDirection: gridArrangeRow
        case .gridFillEmptyCells: gridFillEmptyRow
        case .gridAutoSize: gridDimensionsGroup
        case .monocleOrientation: monocleOrientationRow
        case .monocleHideStyle: monocleHideStyleRow
        case .monocleWrapFocus: monocleWrapFocusRow
        case .trackAxis: trackArrangeRow
        case .trackOverflowStyle: trackOverflowRow
        case .trackNewWindow: trackNewWindowRow
        case .trackNewWindowPosition: trackPositionRow
        case .trackAutoTracks: trackLimitGroup
        case .trackWrapFocus: trackWrapFocusRow
        case .bspNewWindowPlacement:
            PlacementPicker(placement: bsp.newWindowPlacement)
        case .stackNewWindowPlacement:
            PlacementPicker(placement: stack.newWindowPlacement)
        case .scrollingNewWindowPlacement:
            PlacementPicker(
                placement: scrolling.newWindowPlacement
            )
        case .gridNewWindowPlacement:
            PlacementPicker(placement: grid.newWindowPlacement)
        case .monocleNewWindowPlacement:
            PlacementPicker(
                placement: monocle.newWindowPlacement
            )
        case .gridColumns, .gridRows, .trackLimit:
            // Drawn by their Auto toggles' `AutoGatedGroup` above.
            EmptyView()
        case .bspOverrideStrategy, .bspOverrideSplitRatioH,
            .bspOverrideSplitRatioV, .stackOverrideMasterCount,
            .stackOverrideMasterRatio,
            .stackOverrideMasterOrientation,
            .stackOverrideOverflowStyle,
            .stackOverrideStackPosition,
            .scrollingOverrideOrientation,
            .scrollingOverrideAnchor, .scrollingOverrideSlotSize,
            .gridOverrideType, .gridOverrideSplitDirection,
            .gridOverrideFillEmptyCells, .gridOverrideColumns,
            .gridOverrideRows, .gridOverrideAutoSize,
            .monocleOverrideOrientation, .trackOverrideAxis,
            .trackOverrideLimit, .trackOverrideOverflowStyle,
            .trackOverrideAutoTracks:
            let _ = assertionFailure(
                "unrendered Layout Defaults row: \(key.rawValue)"
            )
            EmptyView()
        }
    }

    var bsp: Binding<BspParams> { $model.config.settings.bsp }
    var stack: Binding<StackParams> {
        $model.config.settings.stack
    }
    var scrolling: Binding<ScrollingParams> {
        $model.config.settings.scrolling
    }
    var grid: Binding<GridParams> { $model.config.settings.grid }
    var monocle: Binding<MonocleParams> {
        $model.config.settings.monocle
    }
    var track: Binding<TrackParams> {
        $model.config.settings.track
    }

    var bspStrategyRow: some View {
        SegmentedPicker(
            L("layout_params.split_strategy", "Split strategy"),
            selection: bsp.strategy,
            options: [
                (
                    L(
                        "layout_params.longest_side",
                        "Longest side"
                    ),
                    BspParams.Strategy.longestSide
                ),
                (
                    L("layout_params.alternating", "Alternating"),
                    .alternating
                ),
            ],
            help: LayoutHelp.splitStrategy
        )
    }

    var bspRatioHRow: some View {
        RatioRow(
            label: L(
                "layout_params.split_ratio_h",
                "Width split ratio"
            ),
            value: bsp.splitRatioH,
            help: LayoutHelp.splitRatioH
        )
    }

    var bspRatioVRow: some View {
        RatioRow(
            label: L(
                "layout_params.split_ratio_v",
                "Height split ratio"
            ),
            value: bsp.splitRatioV,
            help: LayoutHelp.splitRatioV
        )
    }

    // MARK: - Stack

    var masterCountRow: some View {
        StepperRow(
            label: L("layout_params.master_count", "Master count"),
            value: stack.masterCount,
            in: 1...10
        )
    }

    var masterRatioRow: some View {
        RatioRow(
            label: L("layout_params.master_ratio", "Master ratio"),
            value: stack.masterRatio
        )
    }

    var masterOrientationRow: some View {
        SegmentedPicker(
            L(
                "layout_params.master_orientation",
                "Master orientation"
            ),
            selection: stack.masterOrientation,
            options: [
                (
                    L(
                        "layout_params.orientation.vertical",
                        "Vertical"
                    ), .vertical
                ),
                (
                    L(
                        "layout_params.orientation.horizontal",
                        "Horizontal"
                    ), .horizontal
                ),
            ],
            help: LayoutHelp.masterOrientation
        )
    }

    var stackPositionRow: some View {
        SegmentedPicker(
            L("layout_params.stack_position", "Stack position"),
            selection: stack.stackPosition,
            options: [
                (L("layout_params.position.top", "Top"), .top),
                (L("layout_params.position.right", "Right"), .right),
                (
                    L("layout_params.position.bottom", "Bottom"),
                    .bottom
                ),
                (L("layout_params.position.left", "Left"), .left),
            ],
            help: LayoutHelp.stackPosition
        )
    }

    var stackOverflowRow: some View {
        SegmentedPicker(
            L("layout_params.overflow", "Overflow"),
            selection: stack.overflowStyle,
            options: overflowOptions,
            help: LayoutHelp.stackOverflow
        )
    }

    /// Shared overflow options for Stack and Track layouts.
    var overflowOptions: [(String, StackParams.OverflowStyle)] {
        [
            (
                L(
                    "layout_params.cascade_overflow",
                    "Cascade overflow"
                ), .cascadeOverflow
            ),
            (
                L("layout_params.cascade_all", "Cascade all"),
                .cascadeAll
            ),
        ]
    }

    var monocleOrientationRow: some View {
        SegmentedPicker(
            L("monocle.focus_orientation", "Focus orientation"),
            selection: monocle.orientation,
            options: [
                (
                    L("scroll_grid.horizontal", "Horizontal"),
                    MonocleParams.Orientation.horizontal
                ),
                (L("scroll_grid.vertical", "Vertical"), .vertical),
            ]
        )
    }

    var monocleHideStyleRow: some View {
        SegmentedPicker(
            L("monocle.hide_style", "Hidden windows"),
            selection: monocle.hideStyle,
            options: [
                (
                    L("monocle.hide_style.stack", "Stack behind"),
                    MonocleParams.HideStyle.stack
                ),
                (
                    L(
                        "monocle.hide_style.park",
                        "Park in corner"
                    ),
                    .park
                ),
            ],
            help: LayoutHelp.monocleHideStyle
        )
    }

    var monocleWrapFocusRow: some View {
        ToggleRow(
            label: L("scroll_grid.wrap_focus", "Wrap focus"),
            isOn: monocle.wrapFocus,
            help: LayoutHelp.wrapFocus
        )
    }
}
