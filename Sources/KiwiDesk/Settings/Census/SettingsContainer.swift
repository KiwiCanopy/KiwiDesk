/// Titled card or group within an area. Spans multiple areas where relevant.
enum SettingsContainer: CaseIterable, Hashable {
    case about
    case advanced
    case appBar
    case borders
    case bsp
    case defaultShortcuts
    case dragAndDrop
    case focus
    case focusBorder
    case gaps
    case general
    case generalKeys
    case grid
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
        case .about, .advanced, .borders, .bsp, .cues,
            .defaultShortcuts, .dragAndDrop,
            .focus, .gaps, .general, .generalKeys, .grid,
            .appliesImmediately, .layers, .luaBindings,
            .monitorFingerprints, .monocle, .mouse,
            .moveWindows, .onQuit, .openApplications,
            .palettes, .perSpaceOverrides,
            .pinnedToDisconnectedMonitors, .presets,
            .profilesPerMacOSSpace, .rulesPerApp,
            .savedProfiles, .scrolling, .sizeAndFloat,
            .spaceList, .spacePlacement, .stack,
            .stickyWindows, .track:
            return nil
        }
    }
}
