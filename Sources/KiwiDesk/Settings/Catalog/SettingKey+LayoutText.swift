/// The row text for the layout-parameter slice — split from
/// `SettingKey+Layout.swift` for the file-size sweet spot.

extension LayoutKey {
    var text: SettingRowText {
        switch self {
        case .bspStrategy, .bspOverrideStrategy:
            return .text(
                "layout_params.split_strategy",
                help: "layout_params.split_strategy.help"
            )
        case .bspSplitRatioH, .bspOverrideSplitRatioH:
            return .text(
                "layout_params.split_ratio_h",
                help: "layout_params.split_ratio_h.help"
            )
        case .bspSplitRatioV, .bspOverrideSplitRatioV:
            return .text(
                "layout_params.split_ratio_v",
                help: "layout_params.split_ratio_v.help"
            )
        case .bspNewWindowPlacement, .stackNewWindowPlacement,
            .scrollingNewWindowPlacement, .gridNewWindowPlacement,
            .monocleNewWindowPlacement:
            return .text(
                "placement.new_window",
                help: "placement.new_window.help"
            )
        case .stackMasterCount, .stackOverrideMasterCount:
            return .text("layout_params.master_count")
        case .stackMasterRatio, .stackOverrideMasterRatio:
            return .text("layout_params.master_ratio")
        case .stackMasterOrientation, .stackOverrideMasterOrientation:
            return .text(
                "layout_params.master_orientation",
                help: "layout_params.master_orientation.help"
            )
        case .stackStackPosition, .stackOverrideStackPosition:
            return .text(
                "layout_params.stack_position",
                help: "layout_params.stack_position.help"
            )
        case .stackOverflowStyle, .trackOverflowStyle,
            .stackOverrideOverflowStyle, .trackOverrideOverflowStyle:
            return .text("layout_params.overflow")
        case .scrollingOrientation:
            return .text("scroll_grid.scroll_orientation")
        case .scrollingAnchor, .scrollingOverrideAnchor:
            return .text("scroll_grid.focus_anchor")
        case .scrollingSlotSizeUnit:
            return .text("slot_size.unit")
        case .scrollingSlotSizeValue, .scrollingOverrideSlotSize:
            return .dynamic
        case .scrollingWrapFocus, .monocleWrapFocus:
            return .text("scroll_grid.wrap_focus")
        case .gridType, .gridOverrideType:
            return .text("scroll_grid.grid_type")
        case .gridSplitDirection, .trackAxis, .gridOverrideSplitDirection,
            .trackOverrideAxis:
            return .text("scroll_grid.arrange")
        case .gridFillEmptySpace, .gridOverrideFillEmptySpace:
            return .text("scroll_grid.fill_empty_space")
        case .gridAutoSize:
            return .text("scroll_grid.auto_size")
        case .gridColumns, .gridOverrideColumns:
            return .text("scroll_grid.columns")
        case .gridRows, .gridOverrideRows:
            return .text("scroll_grid.rows")
        case .monocleOrientation:
            return .text("monocle.focus_orientation")
        case .trackNewWindow:
            return .text("track.new_window")
        case .trackNewWindowPosition:
            return .text(
                "track.new_window_position",
                help: "track.new_window_position.help"
            )
        case .trackAutoTracks:
            return .text("track.auto_tracks")
        case .trackLimit, .trackOverrideLimit:
            return .text("track.limit")
        case .trackWrapFocus:
            return .text("track.wrap_focus")
        case .scrollingOverrideOrientation, .monocleOverrideOrientation:
            return .text("scroll_grid.orientation")
        case .gridOverrideAutoSize, .trackOverrideAutoTracks:
            return .none
        }
    }
}
