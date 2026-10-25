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
    /// KiwiVision ▸ the lens strip and the lens page drawn per live
    /// lens (#2103 rulings 29, 46–54).
    case kiwiVisionLenses
    /// AI ▸ Set up (#1685).
    case aiSetup
    /// AI ▸ Ready-made prompts (#1685).
    case readyMadePrompts
    /// Colors & glass' first role group (#1857): the hue the
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
    /// Shortcuts' Show & hide card: KiwiHub's three sides
    /// (#2265), the bars' show/hide (#761), and KiwiVision's
    /// toggle and lenses (#2312), one sub-group each.
    case showHide
    case kiwishelf
    case appliesImmediately
    case layers
    case looks
    /// Shortcuts' Layout group (#453).
    case layout
    case luaBindings
    case screenFingerprints
    /// Colors & glass' second role group (#1857).
    case secondAccent
    case monocle
    case motion
    case gestures
    /// The Modifier keys card, above the layer header: the Hyper
    /// key (#1870), the base (#2460) and the sides switch (#2601).
    case modifierKeys
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
    /// Colors & glass' window-mark colours (#1857).
    case windowMarks

    /// Container-level gate that greys member rows as a unit.
    var gate: SettingGate? {
        switch self {
        case .glass:
            // The row's own gate HIDES (pre-26); the card greys
            // as a unit under Reduce transparency (#1418), the
            // Motion card's shape.
            return .runtime(.reduceTransparency)
        case .focusBorder:
            return .setting(.borders(.borderEnabled))
        case .motion:
            return .runtime(.reduceMotion)
        case .kiwiVisionLevels:
            // Glass's shape (#1418): the blur greys under Reduce
            // transparency, the dim is exempt.
            return .runtime(.reduceTransparency)
        case .appBar, .spaceBar:
            // A hidden bar's shortcut still shows it, so its style
            // always matters (#761).
            return nil
        case .accent, .advanced, .aiSetup, .readyMadePrompts,
            .kiwiVisionAppearance, .kiwiVisionClear,
            .kiwiVisionNeverDimmed, .kiwiVisionLenses,
            .borders, .bsp,
            .defaultShortcuts, .dragAndDrop, .essentialSettings,
            .focus, .gaps, .general, .grid, .showHide,
            .habits, .kiwishelf, .appliesImmediately, .layers,
            .layout,
            .looks, .luaBindings,
            .screenFingerprints, .monocle, .gestures, .modifierKeys,
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

extension SettingsContainer {
    /// The Colors & glass groups that hold colour rows (#2389):
    /// Liquid Glass and the sheen sit beside them in `.glass`.
    static let colourGroups: Set<SettingsContainer> = [
        .accent, .secondAccent, .kiwishelf, .windowMarks,
    ]
}

extension SettingKey {
    /// A colour row of Colors & glass — the one area a colour
    /// renders in (`SettingsColorSurfaceTests`). Membership is by
    /// container, so a colour placed in another container of the
    /// area escapes the readers of this; the palette-count
    /// equality in `SettingsColorSurfaceTests` is what catches it.
    var isColourRow: Bool {
        placement.area == .coloursAndMotion
            && placement.container.map(
                SettingsContainer.colourGroups.contains
            ) == true
    }
}
