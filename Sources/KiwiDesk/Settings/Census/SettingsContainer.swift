/// Titled card or group within an area. Spans multiple areas where relevant.
enum SettingsContainer: CaseIterable, Hashable {
    case advanced
    case appBar
    case borders
    case bsp
    case defaultShortcuts
    case dragAndDrop
    case essentialSettings
    case focus
    case floatRules
    case focusBorder
    case gaps
    case general
    case glass
    case grid
    case habits
    case kiwishelf
    case appliesImmediately
    case layers
    case looks
    case luaBindings
    case screenFingerprints
    case monocle
    case motion
    case gestures
    case moveWindows
    case openApplications
    case optionalSettings
    case palettes
    case perSpaceOverrides
    case pinnedToDisconnectedScreens
    case presets
    case profilesPerMacOSSpace
    case savedProfiles
    case scrolling
    /// "Shared look" on Looks & Animations (#1752).
    case sharedLook
    case sizeAndFloat
    case spaceBar
    case spaceList
    case spacePlacement
    case spaceRules
    case stack
    case stickyWindows
    case track

    /// Container-level gate that greys member rows as a unit.
    var gate: SettingGate? {
        switch self {
        case .glass:
            // The row's own gate HIDES (pre-26); the card greys
            // as a unit under Reduce transparency (#1418), the
            // Motion card's shape.
            return .runtime(.reduceTransparency)
        case .appBar:
            return .anyOf([
                .layoutAppBar(.monocleAppBarEnabled),
                .layoutAppBar(.scrollingAppBarEnabled),
            ])
        case .spaceBar:
            return .setting(.spaceBar(.spaceBarEnabled))
        case .focusBorder:
            return .setting(.borders(.borderEnabled))
        case .motion:
            return .runtime(.reduceMotion)
        case .advanced, .borders, .bsp,
            .defaultShortcuts, .dragAndDrop, .essentialSettings,
            .focus, .gaps, .general, .grid,
            .habits, .kiwishelf, .appliesImmediately, .layers,
            .looks, .luaBindings,
            .screenFingerprints, .monocle, .gestures,
            .moveWindows, .openApplications,
            .optionalSettings, .palettes, .perSpaceOverrides,
            .pinnedToDisconnectedScreens, .presets,
            .profilesPerMacOSSpace, .floatRules,
            .spaceRules,
            .savedProfiles, .scrolling, .sharedLook, .sizeAndFloat,
            .spaceList, .spacePlacement, .stack,
            .stickyWindows, .track:
            return nil
        }
    }
}
