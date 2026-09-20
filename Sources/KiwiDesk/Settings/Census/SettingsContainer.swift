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
    case focusBorder
    case gaps
    case general
    case generalKeys
    case glass
    case grid
    case habits
    case appliesImmediately
    case layers
    case luaBindings
    case monitorFingerprints
    case monocle
    case motion
    case mouse
    case cues
    case moveWindows
    case onQuit
    case openApplications
    case optionalSettings
    case palettes
    case perSpaceOverrides
    case pinnedToDisconnectedMonitors
    case presets
    case profilesPerMacOSSpace
    case rulesPerApp
    case savedProfiles
    case scrolling
    case sizeAndFloat
    case spaceBar
    case spaceList
    case spacePlacement
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
        case .advanced, .borders, .bsp, .cues,
            .defaultShortcuts, .dragAndDrop, .essentialSettings,
            .focus, .gaps, .general, .generalKeys, .grid,
            .habits, .appliesImmediately, .layers, .luaBindings,
            .monitorFingerprints, .monocle, .mouse,
            .moveWindows, .onQuit, .openApplications,
            .optionalSettings, .palettes, .perSpaceOverrides,
            .pinnedToDisconnectedMonitors, .presets,
            .profilesPerMacOSSpace, .rulesPerApp,
            .savedProfiles, .scrolling, .sizeAndFloat,
            .spaceList, .spacePlacement, .stack,
            .stickyWindows, .track:
            return nil
        }
    }
}
