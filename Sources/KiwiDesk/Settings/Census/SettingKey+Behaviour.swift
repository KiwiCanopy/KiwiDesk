/// Top-level `TilingSettings` behavior knobs.

enum BehaviourKey: String, CaseIterable, Hashable {
    case minWindowSize = "settings.minWindowSize"
    case resizeStep = "settings.resizeStep"
    case refusalSound = "settings.refusalSound"
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
        case .refusalSound:
            // Left Shortcuts ▸ Size & float with #1255: the cue
            // is app-wide now, not a resize setting.
            return .row(.behaviour, .cues, .atRest)
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
        case .refusalSound:
            return .text(
                "behavior.cues.sound",
                help: "behavior.cues.sound.help"
            )
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
