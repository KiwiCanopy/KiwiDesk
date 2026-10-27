/// Display order definitions for Shortcuts settings section (#678,
/// `ShortcutsCensusRenderTests`).
enum ShortcutsRowOrder {
    /// Containers holding a non-empty order list that a bespoke
    /// view draws rather than a standard list loop — Open
    /// applications for its app list, though its KiwiDesk rows
    /// are walked (#1520), and Layout for its cycle list and
    /// switch above the walked shortcuts (#453).
    static let bespokeContainers: Set<SettingsContainer> = [
        .openApplications,
        .layout,
        .layers,
        .luaBindings,
        .defaultShortcuts,
        .gestures,
        .modifierKeys,
        .macosDesktops,
    ]

    /// The Mouse & trackpad drawer's settings, in entry order
    /// (#1726); the drawer's explainer entries are not settings.
    static let gesturesMore: [SettingKey] = [
        .shortcuts(.scrollPan),
        .shortcuts(.scrollLongSwipes),
        .shortcuts(.scrollStepDistance),
        .shortcuts(.scrollSpaceStep),
        .shortcuts(.scrollNaturalTrackpad),
        .shortcuts(.scrollNaturalMouse),
        .behaviour(.mouseHoverFocus),
        .behaviour(.mouseHoverFocusDelay),
        .behaviour(.mouseFollowsFocus),
        .behaviour(.mouseResize),
    ]

    /// Show & hide ▸ KiwiHub order: its sides in the order of their keys,
    /// J K L (#2246, #2265).
    static let kiwiHubAtRest: [SettingKey] = [
        .shortcuts(.jumpToWindow),
        .shortcuts(.showShortcuts),
        .shortcuts(.viewPicker),
    ]

    /// Focus group order: the wrap setting above the direction keys
    /// it governs (#2493), directions, the Space steps, the history
    /// setting above its two rows (#1655), live spaces.
    static let focusAtRest: [SettingKey] = [
        .shortcuts(.focusWrap),
        .shortcuts(.focusDir),
        .shortcuts(.screenLast),
        .shortcuts(.spaceStep),
        .shortcuts(.spaceHistory),
        .shortcuts(.spaceHistoryStep),
        .shortcuts(.goToSpace),
    ]

    /// Show & hide ▸ KiwiVision order: its toggle (#2312), then a row
    /// per lens (#2103 ruling 42).
    static let kiwiVisionAtRest: [SettingKey] = [
        .shortcuts(.toggleKiwiVision),
        .shortcuts(.toggleLens),
    ]

    /// Show & hide ▸ KiwiShelf order: Space Bar first, as in the
    /// Show group (#761).
    static let kiwishelfAtRest: [SettingKey] = [
        .shortcuts(.toggleSpaceBar),
        .shortcuts(.toggleAppBar),
    ]

    /// Move windows group order: swaps, then space moves.
    static let moveWindowsAtRest: [SettingKey] = [
        .shortcuts(.swapDir),
        .shortcuts(.moveToSpace),
        .shortcuts(.moveToSpaceFollow),
    ]

    /// The macOS Desktops section (#2655), after Move windows:
    /// KiwiDesk's own Spaces lead, and a Desktop row is the way
    /// out into macOS. The switch cue first, drawn by
    /// `DesktopCueRow` (#2142); Go to Desktop at rest; the moves,
    /// one interleaved run, behind the section's drawer.
    static let macosDesktopsList: [SettingKey] = [
        .shortcuts(.desktopCue)
    ]

    static let macosDesktopsAtRest: [SettingKey] = [
        .shortcuts(.focusDesktop)
    ]

    static let macosDesktopsMore: [SettingKey] = [
        .shortcuts(.moveToDesktop),
        .shortcuts(.moveToDesktopFollow),
    ]

    /// The Track families, behind their own offer in Move windows
    /// (#1440).
    static let moveWindowsTrackFamilies: [SettingKey] = [
        .shortcuts(.moveWindowToTrack),
        .shortcuts(.swapWithTrack),
    ]

    /// Families whose instances interleave per target rather than stacking.
    static let interleavedRuns: [[SettingKey]] = [
        [.shortcuts(.moveToSpace), .shortcuts(.moveToSpaceFollow)],
        [
            .shortcuts(.moveToDesktop),
            .shortcuts(.moveToDesktopFollow),
        ],
    ]

    /// Interleaved run starting at `key`, if any.
    static func interleavedRun(
        startingAt key: SettingKey
    ) -> [SettingKey]? {
        interleavedRuns.first { $0.first == key }
    }

    /// True if `key` is a non-leading member of an interleaved run.
    static func isInterleavedFollower(_ key: SettingKey) -> Bool {
        interleavedRuns.contains {
            $0.dropFirst().contains(key)
        }
    }

    /// The Layout group's setting rows, above its shortcuts:
    /// the cycle list and the plate's switch (#453, #2144),
    /// drawn by `LayoutCycleRow` and `LayoutCueRow`.
    static let layoutList: [SettingKey] = [
        .shortcuts(.modeCycle),
        .shortcuts(.modeCue),
    ]

    /// The Modifier keys card's rows, drawn by `ModifierKeysCard`:
    /// the Hyper key's recorder (#1870), the move offer under it
    /// (#2460), then the sides switch (#2601).
    static let modifierKeysList: [SettingKey] = [
        .shortcuts(.hyperKey),
        .shortcuts(.shortcutBase),
        .shortcuts(.modifierSides),
    ]

    /// Layout group order (#453): `KeybindingCatalog
    /// .layoutCycleRows` orders the rows inside the cycle family.
    static let layoutAtRest: [SettingKey] = [
        .shortcuts(.layoutCycle)
    ]

    /// Size & float order: resize pairs and the reset that undoes
    /// them (#2303), followed by state toggles.
    static let sizeAndFloatAtRest: [SettingKey] = [
        .shortcuts(.growWidth),
        .shortcuts(.shrinkWidth),
        .shortcuts(.growHeight),
        .shortcuts(.shrinkHeight),
        .shortcuts(.resetSizes),
        .shortcuts(.maximize),
        .shortcuts(.toggleFloating),
        .shortcuts(.toggleSticky),
        .shortcuts(.pocket),
        .shortcuts(.pocketWindow),
    ]

    /// Size & float's `.showMore` tier, empty since #1255 took
    /// its one row to Behaviour. Kept rather than deleted: a
    /// census key authored at this tier reds
    /// `ShortcutsCensusRenderTests` against this list, which is
    /// what says the drawer has to be built again before that
    /// key can draw.
    static let sizeAndFloatMore: [SettingKey] = []

    /// Open applications group order: the per-app list, drawn by
    /// its own view.
    static let openApplicationsAtRest: [SettingKey] = [
        .shortcuts(.openApplications)
    ]

    /// Open applications ▸ KiwiDesk, below the app list (#1520).
    static let openApplicationsKiwiDesk: [SettingKey] = [
        .shortcuts(.openSettings)
    ]

    /// Layers group order behind disclosure.
    static let layersMore: [SettingKey] = [
        .shortcuts(.layers),
        .shortcuts(.layersReach),
        .shortcuts(.layersIcon),
        .shortcuts(.switchToLayer),
    ]

    /// Advanced Lua bindings behind disclosure.
    static let luaBindingsMore: [SettingKey] = [
        .shortcuts(.advanced)
    ]

    /// Header import action.
    static let luaBindingsAtRest: [SettingKey] = [
        .shortcuts(.import)
    ]

    /// Header restore defaults action.
    static let defaultShortcutsAtRest: [SettingKey] = [
        .shortcuts(.restoreDefaults)
    ]
}
