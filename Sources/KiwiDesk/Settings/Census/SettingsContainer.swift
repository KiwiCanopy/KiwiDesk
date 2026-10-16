/// Titled card or group within an area. Spans multiple areas where relevant.
enum SettingsContainer: CaseIterable, Hashable {
    case advanced
    /// KiwiVision ▸ Dim and blur (#2103).
    case kiwiVisionLevels
    /// KiwiVision ▸ System appearance (#2103).
    case kiwiVisionAppearance
    /// KiwiVision ▸ Stays clear (#2103 ruling 18).
    case kiwiVisionClear
    /// KiwiVision ▸ Never dimmed (#2103 rulings 26–27).
    case kiwiVisionNeverDimmed
    /// AI ▸ Set up (#1685).
    case aiSetup
    /// AI ▸ Ready-made prompts (#1685).
    case readyMadePrompts
    /// Advanced Colours' first role group (#1857): the hue the
    /// active Space, the focus border and the drag ghost share.
    case accent
    case appBar
    case borders
    case bsp
    case defaultShortcuts
    case dragAndDrop
    case essentialSettings
    case focus
    case floatRules
    /// App Rules ▸ Automatic floating (#2173).
    case automaticFloating
    case focusBorder
    case gaps
    case general
    case glass
    case grid
    case habits
    /// Shortcuts' KiwiHub group: the key panel's three sides
    /// (#2265).
    case kiwiHub
    /// Shortcuts' KiwiVision group: its toggle and, with #2103
    /// v3, each lens's (#2312).
    case kiwiVisionShortcuts
    case kiwishelf
    case appliesImmediately
    case layers
    case looks
    /// Shortcuts' Layout group (#453).
    case layout
    case luaBindings
    case screenFingerprints
    /// Advanced Colours' second role group (#1857).
    case secondAccent
    case monocle
    case motion
    case gestures
    /// The Hyper key's one row, above the layer header (#1870).
    case hyperKey
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
    /// Advanced Colours' window-mark colours (#1857).
    case windowMarks

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
        case .kiwiVisionLevels:
            // Glass's shape (#1418): the blur greys under Reduce
            // transparency, the dim is exempt.
            return .runtime(.reduceTransparency)
        case .accent, .advanced, .aiSetup, .readyMadePrompts,
            .kiwiVisionAppearance, .kiwiVisionClear,
            .kiwiVisionNeverDimmed,
            .borders, .bsp,
            .defaultShortcuts, .dragAndDrop, .essentialSettings,
            .focus, .gaps, .general, .grid, .kiwiHub,
            .kiwiVisionShortcuts,
            .habits, .kiwishelf, .appliesImmediately, .layers,
            .layout,
            .looks, .luaBindings,
            .screenFingerprints, .monocle, .gestures, .hyperKey,
            .moveWindows, .openApplications,
            .optionalSettings, .palettes, .perSpaceOverrides,
            .pinnedToDisconnectedScreens, .presets,
            .profilesPerMacOSSpace, .floatRules, .secondAccent,
            .spaceRules, .automaticFloating,
            .savedProfiles, .scrolling, .sharedLook, .sizeAndFloat,
            .spaceList, .spacePlacement, .stack,
            .stickyWindows, .track, .windowMarks:
            return nil
        }
    }
}
