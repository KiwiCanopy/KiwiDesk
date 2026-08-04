/// A titled card or group within an area. Several containers
/// deliberately span TWO areas (`.appBar`, `.spaceBar`,
/// `.borders`, `.dragAndDrop`, `.scrolling` appear in both a
/// home area and Advanced Colours / Layout Defaults), and the
/// spanning is load-bearing: it is what carries a container
/// gate onto both surfaces. Never normalize to per-area
/// containers.
enum SettingsContainer: CaseIterable, Hashable {
    case about
    case advanced
    case appBar
    case borders
    case bsp
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

    /// The gate that greys this container's rows AS A UNIT,
    /// where the live editor greys wholesale (the App Bar and
    /// Space Bar editors off their bar-shown switches, Focus
    /// border off its enable toggle, the animations card under
    /// macOS Reduce Motion). Composes with each row's own
    /// `SettingPlacement.gate` (both apply). There is ONE
    /// escape and it is data, never prose: any row that must
    /// stay live while its container greys — the gate's own
    /// owner toggles included, or a lockout follows — sets
    /// `exemptFromContainerGate`, and the census guards pin
    /// that every in-container owner does. Containers whose
    /// greys have no single owning switch (Drag & drop's two
    /// halves) record nothing here — the row gates carry the
    /// owners.
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
        case .about, .advanced, .borders, .bsp, .dragAndDrop,
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
