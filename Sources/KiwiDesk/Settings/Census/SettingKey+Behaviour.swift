/// Top-level `TilingSettings` behavior knobs.

enum BehaviourKey: String, CaseIterable, Hashable {
    case minWindowSize = "settings.minWindowSize"
    case resizeStep = "settings.resizeStep"
    case resizeFeedback = "settings.resizeFeedback"
    case swapSkipsCascade = "settings.swapSkipsCascade"
    case floatNudge = "settings.floatNudge"
    case floatScaleOnDisplayChange = "settings.floatScaleOnDisplayChange"
    case placementOverride = "settings.placementOverride[space]"
    case quitLayout = "settings.quitLayout"
    case quitGridTargetDepth = "settings.quitGridTargetDepth"
    case mouseResize = "settings.mouseResize"
    case mouseFollowsFocus = "settings.mouse.followsFocus"
}

extension BehaviourKey {
    var placement: SettingPlacement {
        switch self {
        case .minWindowSize:
            return .row(.layoutDefaults, .general, .atRest)
        case .resizeStep, .swapSkipsCascade, .floatNudge,
            .floatScaleOnDisplayChange, .placementOverride, .quitLayout:
            return .luaOnly
        case .resizeFeedback:
            return .row(.shortcuts, .sizeAndFloat, .showMore)
        case .quitGridTargetDepth:
            return .row(.behaviour, .onQuit, .atRest)
        case .mouseResize, .mouseFollowsFocus:
            return .row(.behaviour, .mouse, .atRest)
        }
    }
}

extension BehaviourKey {
    var text: SettingRowText {
        switch self {
        case .minWindowSize:
            return .text("layout_defaults.min_window_size")
        case .resizeStep, .swapSkipsCascade, .floatNudge,
            .floatScaleOnDisplayChange, .placementOverride, .quitLayout:
            return .none
        case .resizeFeedback:
            return .text("shortcuts.size_float.feedback")
        case .quitGridTargetDepth:
            return .text(
                "behavior.quit.target_depth",
                help: "behavior.quit.target_depth.help"
            )
        case .mouseResize:
            return .text(
                "behavior.mouse.resize_action",
                help: "behavior.mouse.resize_action.help"
            )
        case .mouseFollowsFocus:
            return .text("behavior.mouse.follows_focus")
        }
    }
}
