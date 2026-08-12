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
    case gridFillEmptyCells = "settings.grid.fillEmptyCells"
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
    case gridOverrideFillEmptyCells =
        "settings.grid.override[space].fillEmptyCells"
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
            // Orientation only matters with several masters —
            // and "several" is the RESOLVED count (#406), since
            // a space overriding the count to 3 is reading this
            // orientation whatever the global says. Both owners
            // are surfaced, so both are named, exactly as the
            // per-space twin below already does.
            return .row(
                .layoutDefaults,
                .stack,
                .atRest,
                gate: .anyOf([
                    .layout(.stackMasterCount),
                    .layout(.stackOverrideMasterCount),
                ])
            )
        case .scrollingOrientation, .scrollingAnchor, .scrollingSlotSizeUnit,
            .scrollingSlotSizeValue, .scrollingNewWindowPlacement,
            .scrollingWrapFocus:
            return .row(.layoutDefaults, .scrolling, .atRest)
        case .gridType, .gridSplitDirection, .gridAutoSize,
            .gridNewWindowPlacement:
            return .row(.layoutDefaults, .grid, .atRest)
        case .gridFillEmptyCells:
            // Inert while the RESOLVED grid type is rigid —
            // global rigid with no dynamic override
            // (GridEditor.fillEmptyIsInert), so both owners.
            return .row(
                .layoutDefaults,
                .grid,
                .atRest,
                gate: .anyOf([
                    .layout(.gridType),
                    .layout(.gridOverrideType),
                ])
            )
        case .gridColumns, .gridRows:
            // Auto-size grid supplies both dimensions
            // (AutoGatedGroup greys the pair).
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
            .gridOverrideType, .gridOverrideSplitDirection,
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
        case .gridOverrideFillEmptyCells:
            return .row(
                .spacesAndLayouts,
                .perSpaceOverrides,
                .atRest,
                gate: .anyOf([
                    .layout(.gridType),
                    .layout(.gridOverrideType),
                ])
            )
        case .gridOverrideColumns, .gridOverrideRows:
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
