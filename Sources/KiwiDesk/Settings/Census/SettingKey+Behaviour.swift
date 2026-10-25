import KiwiDeskCore

/// Top-level `TilingSettings` behavior knobs.

enum BehaviourKey: String, CaseIterable, Hashable {
    case minWindowSize = "settings.minWindowSizes (master)"
    case minSizeStackWidth = "settings.minWindowSizes.stack.width"
    case minSizeStackHeight = "settings.minWindowSizes.stack.height"
    case minSizeGridWidth = "settings.minWindowSizes.grid.width"
    case minSizeGridHeight = "settings.minWindowSizes.grid.height"
    case minSizeTrackWidth = "settings.minWindowSizes.track.width"
    case minSizeTrackHeight = "settings.minWindowSizes.track.height"
    case minSizeBspWidth = "settings.minWindowSizes.bsp.width"
    case minSizeBspHeight = "settings.minWindowSizes.bsp.height"
    case minSizeScrollingWidth = "settings.minWindowSizes.scrolling.width"
    case minSizeScrollingHeight = "settings.minWindowSizes.scrolling.height"
    case minSizeFloatingWidth = "settings.minWindowSizes.floating.width"
    case minSizeFloatingHeight = "settings.minWindowSizes.floating.height"
    case minSizePerSpaceOverride = "settings.minWindowSizeOverride[space]"
    case resizeStep = "settings.resizeStep"
    case swapSkipsCascade = "settings.swapSkipsCascade"
    case floatPlacement = "settings.floatPlacement"
    case floatScaleOnDisplayChange = "settings.floatScaleOnDisplayChange"
    case placementOverride = "settings.placementOverride[space]"
    case mouseResize = "settings.mouseResize"
    case mouseFollowsFocus = "settings.mouse.followsFocus"
    case mouseHoverFocus = "settings.mouse.hoverFocus"
    case mouseHoverFocusDelay = "settings.mouse.hoverFocusDelayMS"
    // KiwiHub's navigation key alternatives (#2600), Lua-only.
    case kiwiHubKeyUp = "settings.kiwihub.key.up"
    case kiwiHubKeyDown = "settings.kiwihub.key.down"
    case kiwiHubKeyPageUp = "settings.kiwihub.key.pageUp"
    case kiwiHubKeyPageDown = "settings.kiwihub.key.pageDown"
    case kiwiHubKeyLeft = "settings.kiwihub.key.left"
    case kiwiHubKeyRight = "settings.kiwihub.key.right"
}

extension BehaviourKey {
    /// The built-in KiwiHub key a census row mirrors, if any.
    var kiwiHubKey: KiwiHubKey? {
        switch self {
        case .kiwiHubKeyUp: return .up
        case .kiwiHubKeyDown: return .down
        case .kiwiHubKeyPageUp: return .pageUp
        case .kiwiHubKeyPageDown: return .pageDown
        case .kiwiHubKeyLeft: return .left
        case .kiwiHubKeyRight: return .right
        default: return nil
        }
    }
}

extension BehaviourKey {
    var placement: SettingPlacement {
        switch self {
        case .minWindowSize:
            // Live while layouts differ (#2237): its axis reads
            // "Mixed" and its `?` acknowledges, never a grey.
            return .row(.layoutDefaults, .general, .atRest)
        case .minSizeStackWidth,
            .minSizeStackHeight,
            .minSizeGridWidth,
            .minSizeGridHeight,
            .minSizeTrackWidth,
            .minSizeTrackHeight,
            .minSizeBspWidth,
            .minSizeBspHeight,
            .minSizeScrollingWidth,
            .minSizeScrollingHeight,
            .minSizeFloatingWidth,
            .minSizeFloatingHeight:
            // The master's "Per layout" drawer (#2237).
            return .row(.layoutDefaults, .general, .showMore)
        case .minSizePerSpaceOverride:
            // A Space's own floor (#2422), beside its gaps; inert
            // while the Space is Monocle, which applies none.
            return .row(
                .spacesAndLayouts,
                .perSpaceOverrides,
                .atRest,
                gate: .setting(.spaces(.spaceModes))
            )
        case .resizeStep, .swapSkipsCascade, .floatPlacement,
            .floatScaleOnDisplayChange, .placementOverride,
            .kiwiHubKeyUp, .kiwiHubKeyDown, .kiwiHubKeyPageUp,
            .kiwiHubKeyPageDown, .kiwiHubKeyLeft, .kiwiHubKeyRight:
            return .luaOnly
        case .mouseResize, .mouseFollowsFocus, .mouseHoverFocus,
            .mouseHoverFocusDelay:
            // Moved from Behavior with #1726: the Mouse &
            // trackpad drawer explains the gestures they tune.
            return .row(.shortcuts, .gestures, .showMore)
        }
    }
}

extension BehaviourKey {
    var text: SettingRowText {
        switch self {
        case .minWindowSize:
            return .text("layout_defaults.min_window_size")
        case .minSizeStackWidth:
            return .text("layout_defaults.min_size.stack_width")
        case .minSizeStackHeight:
            return .text("layout_defaults.min_size.stack_height")
        case .minSizeGridWidth:
            return .text("layout_defaults.min_size.grid_width")
        case .minSizeGridHeight:
            return .text("layout_defaults.min_size.grid_height")
        case .minSizeTrackWidth:
            return .text("layout_defaults.min_size.track_width")
        case .minSizeTrackHeight:
            return .text("layout_defaults.min_size.track_height")
        case .minSizeBspWidth:
            return .text("layout_defaults.min_size.bsp_width")
        case .minSizeBspHeight:
            return .text("layout_defaults.min_size.bsp_height")
        case .minSizeScrollingWidth:
            return .text("layout_defaults.min_size.scrolling_width")
        case .minSizeScrollingHeight:
            return .text("layout_defaults.min_size.scrolling_height")
        case .minSizeFloatingWidth:
            return .text("layout_defaults.min_size.floating_width")
        case .minSizeFloatingHeight:
            return .text("layout_defaults.min_size.floating_height")
        case .minSizePerSpaceOverride:
            return .text(
                "layout_defaults.min_window_size",
                help: "space_override.min_size.help"
            )
        case .resizeStep, .swapSkipsCascade, .floatPlacement,
            .floatScaleOnDisplayChange, .placementOverride,
            .kiwiHubKeyUp, .kiwiHubKeyDown, .kiwiHubKeyPageUp,
            .kiwiHubKeyPageDown, .kiwiHubKeyLeft, .kiwiHubKeyRight:
            return .none
        case .mouseHoverFocusDelay:
            return .text("behavior.mouse.hover_focus_delay")
        case .mouseResize:
            return .text(
                "behavior.mouse.resize_action",
                help: "behavior.mouse.resize_action.help"
            )
        case .mouseFollowsFocus:
            return .text("behavior.mouse.follows_focus")
        case .mouseHoverFocus:
            return .text(
                "behavior.mouse.hover_focus",
                help: "behavior.mouse.hover_focus.help"
            )
        }
    }
}
