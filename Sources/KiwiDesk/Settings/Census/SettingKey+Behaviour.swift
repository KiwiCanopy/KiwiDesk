/// Top-level `TilingSettings` behavior knobs.

enum BehaviourKey: String, CaseIterable, Hashable {
    case minWindowSize = "settings.minWindowSize"
    case resizeStep = "settings.resizeStep"
    case swapSkipsCascade = "settings.swapSkipsCascade"
    case floatPlacement = "settings.floatPlacement"
    case floatScaleOnDisplayChange = "settings.floatScaleOnDisplayChange"
    case placementOverride = "settings.placementOverride[space]"
    case mouseResize = "settings.mouseResize"
    case mouseFollowsFocus = "settings.mouse.followsFocus"
}

extension BehaviourKey {
    var placement: SettingPlacement {
        switch self {
        case .minWindowSize:
            return .row(.layoutDefaults, .general, .atRest)
        case .resizeStep, .swapSkipsCascade, .floatPlacement,
            .floatScaleOnDisplayChange, .placementOverride:
            return .luaOnly
        case .mouseResize, .mouseFollowsFocus:
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
        case .resizeStep, .swapSkipsCascade, .floatPlacement,
            .floatScaleOnDisplayChange, .placementOverride:
            return .none
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
