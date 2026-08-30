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

    /// Focus group order: directions, live spaces, macOS Desktops.
    static let focusAtRest: [SettingKey] = [
        .shortcuts(.focusDir),
        .shortcuts(.goToSpace),
        .shortcuts(.focusDesktop),
    ]

    /// Move windows group order: swaps, track verbs, space moves, Desktop
    /// moves.
    static let moveWindowsAtRest: [SettingKey] = [
        .shortcuts(.swapDir),
        .shortcuts(.moveWindowToTrack),
        .shortcuts(.swapWithTrack),
        .shortcuts(.moveToSpace),
        .shortcuts(.moveToSpaceFollow),
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

    /// Unsupported resize sound cue setting.
    static let sizeAndFloatMore: [SettingKey] = [
        .behaviour(.resizeFeedback)
    ]

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
