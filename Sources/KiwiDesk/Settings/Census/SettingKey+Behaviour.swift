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
    /// Maximize Height's width share, Maximize Width's height share
    /// and where both grow from, each per screen shape (#3062).
    case maximizeHeightShare = "settings.maximize.heightShare"
    case maximizeWidthShare = "settings.maximize.widthShare"
    case maximizeAnchor = "settings.maximize.anchor"
    /// A Space's own Maximize Height and Width shares and anchor,
    /// over its screen shape's (#3090).
    case maximizeHeightSharePerSpace =
        "settings.maximize.shareOverride[space].height"
    case maximizeWidthSharePerSpace =
        "settings.maximize.shareOverride[space].width"
    case maximizeAnchorPerSpace = "settings.maximize.anchorOverride[space]"
    /// Whether a new Maximize follows focus (#3063), Lua-only.
    case maximizeFollowFocus = "settings.maximize.followFocus"
    case resizeStep = "settings.resizeStep"
    case swapSkipsCascade = "settings.swapSkipsCascade"
    case floatPlacement = "settings.floatPlacement"
    case floatScaleOnDisplayChange = "settings.floatScaleOnDisplayChange"
    case placementOverride = "settings.placementOverride[space]"
    case mouseResize = "settings.mouseResize"
    case mouseFollowsFocus = "settings.mouse.followsFocus"
    case mouseHoverFocus = "settings.mouse.hoverFocus"
    case mouseHoverFocusDelay = "settings.mouse.hoverFocusDelayMS"
    /// The tiling toggle's start value and ticks (#3008, #3089):
    /// rows in Size & float; the per-Space start and the app-wide
    /// bases, which a row's All profiles writes, stay Lua-only.
    case tilingStart = "settings.tiling.start"
    case tilingStartOverride = "settings.tiling.startOverride[space]"
    case tilingOffHidesBorders = "settings.tiling.offHidesBorders"
    case tilingOffHidesBars = "settings.tiling.offHidesBars"
    case tilingStartGlobal = "appWide.tilingStartGlobal"
    case tilingOffHidesBordersGlobal = "appWide.tilingOffHidesBorders"
    case tilingOffHidesBarsGlobal = "appWide.tilingOffHidesBars"
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
        case .maximizeHeightShare, .maximizeWidthShare, .maximizeAnchor:
            // Never greyed: the verb reads them whether or not a
            // chord is bound (#3062).
            return .row(.layoutDefaults, .maximize, .atRest)
        case .maximizeHeightSharePerSpace, .maximizeWidthSharePerSpace,
            .maximizeAnchorPerSpace:
            // Never greyed: a Floating Space maximizes its floats and
            // a Monocle one its floats (#3090).
            return .row(.spacesAndLayouts, .perSpaceOverrides, .atRest)
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
            .maximizeFollowFocus, .tilingStartOverride, .tilingStartGlobal,
            .tilingOffHidesBordersGlobal, .tilingOffHidesBarsGlobal:
            return .luaOnly
        case .tilingStart:
            // Never greyed: the menu row and Lua pause tiling too.
            return .row(.shortcuts, .sizeAndFloat, .atRest)
        case .tilingOffHidesBorders:
            return .row(
                .shortcuts,
                .sizeAndFloat,
                .atRest,
                gate: .runtime(.focusBorderOff)
            )
        case .tilingOffHidesBars:
            return .row(
                .shortcuts,
                .sizeAndFloat,
                .atRest,
                gate: .runtime(.noBarShows)
            )
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
        case .maximizeHeightShare:
            return .text("layout_defaults.maximize.height_share")
        case .maximizeWidthShare:
            return .text("layout_defaults.maximize.width_share")
        case .maximizeAnchor:
            return .text("layout_defaults.maximize.anchor")
        case .maximizeHeightSharePerSpace:
            return .text("layout_defaults.maximize.height_share")
        case .maximizeWidthSharePerSpace:
            return .text("layout_defaults.maximize.width_share")
        case .maximizeAnchorPerSpace:
            return .text("layout_defaults.maximize.anchor")
        case .minSizePerSpaceOverride:
            return .text(
                "layout_defaults.min_window_size",
                help: "space_override.min_size.help"
            )
        case .resizeStep, .swapSkipsCascade, .floatPlacement,
            .floatScaleOnDisplayChange, .placementOverride,
            .maximizeFollowFocus, .tilingStartOverride, .tilingStartGlobal,
            .tilingOffHidesBordersGlobal, .tilingOffHidesBarsGlobal:
            return .none
        case .tilingStart:
            return .text(
                "shortcuts.tiling_off.start",
                help: "shortcuts.tiling_off.start.help"
            )
        case .tilingOffHidesBorders:
            return .text("shortcuts.tiling_off.hide_borders")
        case .tilingOffHidesBars:
            return .text("shortcuts.tiling_off.hide_bars")
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
