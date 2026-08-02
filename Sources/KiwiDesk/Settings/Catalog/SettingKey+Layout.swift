/// Layout algorithm parameters (`LayoutParams`), defaults and
/// per-space overrides.

enum LayoutKey: String, CaseIterable, Hashable {
    case bspStrategy = "settings.bsp.strategy"
    case bspSplitRatioH = "settings.bsp.splitRatioH"
    case bspSplitRatioV = "settings.bsp.splitRatioV"
    case bspNewWindowPlacement = "settings.bsp.newWindowPlacement"
    case stackMasterCount = "settings.stack.masterCount"
    case stackMasterRatio = "settings.stack.masterRatio"
    case stackMasterOrientation = "settings.stack.masterOrientation"
    case stackStackPosition = "settings.stack.stackPosition"
    case stackOverflowStyle = "settings.stack.overflowStyle"
    case stackNewWindowPlacement = "settings.stack.newWindowPlacement"
    case scrollingOrientation = "settings.scrolling.orientation"
    case scrollingAnchor = "settings.scrolling.anchor"
    case scrollingSlotSizeUnit = "settings.scrolling.slotSize (unit)"
    case scrollingSlotSizeValue = "settings.scrolling.slotSize (value)"
    case scrollingNewWindowPlacement = "settings.scrolling.newWindowPlacement"
    case scrollingWrapFocus = "settings.scrolling.wrapFocus"
    case gridType = "settings.grid.type"
    case gridSplitDirection = "settings.grid.splitDirection"
    case gridFillEmptySpace = "settings.grid.fillEmptySpace"
    case gridAutoSize = "settings.grid.autoSize"
    case gridColumns = "settings.grid.columns"
    case gridRows = "settings.grid.rows"
    case gridNewWindowPlacement = "settings.grid.newWindowPlacement"
    case monocleOrientation = "settings.monocle.orientation"
    case monocleWrapFocus = "settings.monocle.wrapFocus"
    case monocleNewWindowPlacement = "settings.monocle.newWindowPlacement"
    case trackAxis = "settings.track.axis"
    case trackOverflowStyle = "settings.track.overflowStyle"
    case trackNewWindow = "settings.track.newWindow"
    case trackNewWindowPosition = "settings.track.newWindowPosition"
    case trackAutoTracks = "settings.track.autoTracks"
    case trackLimit = "settings.track.limit"
    case trackWrapFocus = "settings.track.wrapFocus"
    case bspOverrideStrategy = "settings.bsp.override[space].strategy"
    case bspOverrideSplitRatioH = "settings.bsp.override[space].splitRatioH"
    case bspOverrideSplitRatioV = "settings.bsp.override[space].splitRatioV"
    case stackOverrideMasterCount =
        "settings.stack.override[space].masterCount"
    case stackOverrideMasterRatio =
        "settings.stack.override[space].masterRatio"
    case stackOverrideOverflowStyle =
        "settings.stack.override[space].overflowStyle"
    case stackOverrideStackPosition =
        "settings.stack.override[space].stackPosition"
    case stackOverrideMasterOrientation =
        "settings.stack.override[space].masterOrientation"
    case scrollingOverrideOrientation =
        "settings.scrolling.override[space].orientation"
    case scrollingOverrideAnchor = "settings.scrolling.override[space].anchor"
    case scrollingOverrideSlotSize =
        "settings.scrolling.override[space].slotSize"
    case gridOverrideType = "settings.grid.override[space].type"
    case gridOverrideFillEmptySpace =
        "settings.grid.override[space].fillEmptySpace"
    case gridOverrideSplitDirection =
        "settings.grid.override[space].splitDirection"
    case gridOverrideColumns = "settings.grid.override[space].columns"
    case gridOverrideRows = "settings.grid.override[space].rows"
    case gridOverrideAutoSize = "settings.grid.override[space].autoSize"
    case monocleOverrideOrientation =
        "settings.monocle.override[space].orientation"
    case trackOverrideAxis = "settings.track.override[space].axis"
    case trackOverrideLimit = "settings.track.override[space].limit"
    case trackOverrideOverflowStyle =
        "settings.track.override[space].overflowStyle"
    case trackOverrideAutoTracks = "settings.track.override[space].autoTracks"
}

extension LayoutKey {
    var placement: SettingPlacement {
        switch self {
        case .bspStrategy, .bspSplitRatioH, .bspSplitRatioV,
            .bspNewWindowPlacement:
            return .row(.layoutDefaults, .bsp, .atRest)
        case .stackMasterCount, .stackMasterRatio, .stackStackPosition,
            .stackOverflowStyle, .stackNewWindowPlacement:
            return .row(.layoutDefaults, .stack, .atRest)
        case .stackMasterOrientation:
            // Orientation only matters with several masters.
            return .row(
                .layoutDefaults,
                .stack,
                .atRest,
                gate: .setting(.layout(.stackMasterCount))
            )
        case .scrollingOrientation, .scrollingAnchor, .scrollingSlotSizeUnit,
            .scrollingSlotSizeValue, .scrollingNewWindowPlacement,
            .scrollingWrapFocus:
            return .row(.layoutDefaults, .scrolling, .atRest)
        case .gridType, .gridSplitDirection, .gridAutoSize, .gridRows,
            .gridNewWindowPlacement:
            return .row(.layoutDefaults, .grid, .atRest)
        case .gridFillEmptySpace:
            // Inert while the grid is rigid (resolved across
            // overrides — GridEditor.fillEmptyIsInert).
            return .row(
                .layoutDefaults,
                .grid,
                .atRest,
                gate: .setting(.layout(.gridType))
            )
        case .gridColumns:
            // Auto-size grid supplies the dimensions.
            return .row(
                .layoutDefaults,
                .grid,
                .atRest,
                gate: .setting(.layout(.gridAutoSize))
            )
        case .monocleOrientation, .monocleWrapFocus,
            .monocleNewWindowPlacement:
            return .row(.layoutDefaults, .monocle, .atRest)
        case .trackAxis, .trackOverflowStyle, .trackNewWindow,
            .trackNewWindowPosition, .trackAutoTracks, .trackWrapFocus:
            return .row(.layoutDefaults, .track, .atRest)
        case .trackLimit:
            // Auto track limit pins it.
            return .row(
                .layoutDefaults,
                .track,
                .atRest,
                gate: .setting(.layout(.trackAutoTracks))
            )
        case .bspOverrideStrategy, .bspOverrideSplitRatioH,
            .bspOverrideSplitRatioV, .stackOverrideMasterCount,
            .stackOverrideMasterRatio, .stackOverrideOverflowStyle,
            .stackOverrideStackPosition, .scrollingOverrideOrientation,
            .scrollingOverrideAnchor, .scrollingOverrideSlotSize,
            .gridOverrideType, .gridOverrideSplitDirection, .gridOverrideRows,
            .monocleOverrideOrientation, .trackOverrideAxis,
            .trackOverrideOverflowStyle:
            return .row(.spacesAndLayouts, .perSpaceOverrides, .atRest)
        // The override rows grey on the RESOLVED value
        // (override ?? global, #406), so their gates name both
        // surfaced owners; where the override side is Lua-only
        // (auto-size, auto-tracks) only the global row remains.
        case .stackOverrideMasterOrientation:
            return .row(
                .spacesAndLayouts,
                .perSpaceOverrides,
                .atRest,
                gate: .anyOf([
                    .layout(.stackMasterCount),
                    .layout(.stackOverrideMasterCount),
                ])
            )
        case .gridOverrideFillEmptySpace:
            return .row(
                .spacesAndLayouts,
                .perSpaceOverrides,
                .atRest,
                gate: .anyOf([
                    .layout(.gridType),
                    .layout(.gridOverrideType),
                ])
            )
        case .gridOverrideColumns:
            return .row(
                .spacesAndLayouts,
                .perSpaceOverrides,
                .atRest,
                gate: .setting(.layout(.gridAutoSize))
            )
        case .trackOverrideLimit:
            return .row(
                .spacesAndLayouts,
                .perSpaceOverrides,
                .atRest,
                gate: .setting(.layout(.trackAutoTracks))
            )
        case .gridOverrideAutoSize, .trackOverrideAutoTracks:
            return .luaOnly
        }
    }
}

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
