/// Display order definitions for Shortcuts settings section (#678,
/// `ShortcutsCensusRenderTests`).
enum ShortcutsRowOrder {
    /// Containers drawn with bespoke views rather than a standard list loop.
    static let bespokeContainers: Set<SettingsContainer> = [
        .openApplications,
        .layers,
        .luaBindings,
        .defaultShortcuts,
    ]

    /// Focus group order: directions, then live spaces.
    static let focusAtRest: [SettingKey] = [
        .shortcuts(.focusDir),
        .shortcuts(.goToSpace),
    ]

    /// Move windows group order: swaps, track verbs, space moves.
    static let moveWindowsAtRest: [SettingKey] = [
        .shortcuts(.swapDir),
        .shortcuts(.moveWindowToTrack),
        .shortcuts(.swapWithTrack),
        .shortcuts(.moveToSpace),
        .shortcuts(.moveToSpaceFollow),
    ]

    /// The Desktop families, last in each group and behind their
    /// own offer until one is bound (#1125). Named apart from
    /// the catalog's `focusDesktops` / `moveWindowsDesktops`
    /// drawers: `SettingsCatalogSiteTests` greps a bare
    /// `.<name>`, so a byte-identical name here would satisfy
    /// the dead-declaration guard on this mention alone. KiwiDesk's own
    /// Spaces lead — a Desktop row is the escape into macOS's
    /// arrangement — which is what `focusAtRest`'s ordering
    /// already said and this extends from ORDER into VISIBILITY.
    static let focusDesktopFamilies: [SettingKey] = [
        .shortcuts(.focusDesktop)
    ]

    static let moveWindowsDesktopFamilies: [SettingKey] = [
        .shortcuts(.moveToDesktop),
        .shortcuts(.moveToDesktopFollow),
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

    /// Size & float order: resize pairs followed by state toggles.
    static let sizeAndFloatAtRest: [SettingKey] = [
        .shortcuts(.growWidth),
        .shortcuts(.shrinkWidth),
        .shortcuts(.growHeight),
        .shortcuts(.shrinkHeight),
        .shortcuts(.toggleFloating),
        .shortcuts(.toggleSticky),
        .shortcuts(.toggleDisplaySticky),
    ]

    /// Empty since #1255 took the sound cue to Behaviour: the
    /// drawer it filled is gone with it, so this list holds the
    /// area's promise that a `.showMore` tier here would need
    /// one built again.
    static let sizeAndFloatMore: [SettingKey] = []

    /// Open applications group order.
    static let openApplicationsAtRest: [SettingKey] = [
        .shortcuts(.openApplications)
    ]

    /// General shortcuts behind disclosure.
    static let generalKeysMore: [SettingKey] = [
        .shortcuts(.showShortcuts),
        .shortcuts(.openSettings),
    ]

    /// Layers group order behind disclosure.
    static let layersMore: [SettingKey] = [
        .shortcuts(.layers),
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
