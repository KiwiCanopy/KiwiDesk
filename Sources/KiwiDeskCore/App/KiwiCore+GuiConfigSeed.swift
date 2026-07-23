import Foundation

/// The "seed / overlay a `GuiConfig` from live or stored-profile
/// state" helpers behind `loadGuiConfig()` / `loadGuiConfig(
/// editing:)` — split out of `KiwiCore+GuiConfig.swift` to stay
/// under the file-size ceiling.
extension KiwiCore {
    /// Copies a *stored* profile's tiling into the model —
    /// sibling of `overlayLiveProfileState`, reading the profile
    /// instead of live state. Pins come from the set covering the
    /// connected monitors (empty when none matches, i.e. the
    /// Canvas can't be edited for this profile right now).
    func overlayProfileState(
        _ config: inout GuiConfig,
        from profile: Profile
    ) {
        config.settings = profile.settings
        config.spaceModes = profile.spaceModes
        config.mainSpaces = Set(profile.mainSpaces)
        let live = state.workspaces.allDisplays
            .map(\.fingerprint)
        config.spacePins =
            profile.set(matching: live)?.spaceMonitorMap ?? [:]
        // The space set is the profile's own — NOT unioned with
        // the live sidecar's spaces, or editing a profile for
        // other hardware would graft this machine's spaces into
        // it on save (mirrors `applyProfileScopedState`, #18).
        // Stored order is authoritative (#75); `orderedSpaces`
        // appends any declared space absent from the list.
        config.spaces = profile.orderedSpaces
        config.fallbackSpace = profile.fallbackSpace
        // Shortcuts tab in override mode (#55 phase 7): the
        // tabs edit the RESOLVED modes (base + this profile's
        // sparse override); `overwriteProfile` diffs them back
        // against the base on save.
        config.modes = ConfigResolver.resolvedModes(
            base: config.modes,
            profile: profile.modes
        )
        // App Rules tab in override mode (#109): same
        // resolve-edit-diff cycle over the flat rule map.
        config.appRules = ConfigResolver.resolvedAppRules(
            base: config.appRules,
            profile: profile.appRules
        )
        config.floatRules =
            profile.floatRules?.resolved(
                onto: config.floatRules,
                normalizing: FloatRules.normalizedRule
            ) ?? config.floatRules
        config.ignoreRules =
            profile.ignoreRules?.resolved(
                onto: config.ignoreRules,
                normalizing: IgnoreRules.normalizedRule
            ) ?? config.ignoreRules
    }

    /// Copies the live profile-scoped state into the model:
    /// tiling settings, per-space modes, monitor pins, and the
    /// Main role.
    func overlayLiveProfileState(
        _ config: inout GuiConfig
    ) {
        config.settings = tiler.settings
        var modes: [SpaceID: LayoutMode] = [:]
        var live: [SpaceID] = []
        for space in state.workspaces.allSpaces {
            live.append(space.id)
            if space.mode != .bsp {
                modes[space.id] = space.mode
            }
        }
        config.spaceModes = modes
        // Live state is authoritative for which spaces EXIST
        // and for their ORDER (#75/#55): every profile apply
        // and every GUI save reconciles the live order via
        // `WorkspaceManager.reorder`, so the live list already
        // carries the chosen display order — while the
        // sidecar's list can be stale (e.g. right after
        // loading a profile whose order differs). A bare space
        // only in `gui.json` is seeded into live at boot
        // (`seedGuiSpaces`, #77), so it is present here too.
        config.spaces = SpaceID.deduplicated(live)
        config.spacePins = spacePins
        config.mainSpaces = mainSpaces
        config.fallbackSpace = fallbackSpace
    }

    /// Save-time freshness net for the dashboard: appends
    /// spaces that appeared live *after* the model was seeded
    /// (a profile load or a hotkey-created space while the
    /// dashboard sat open). Without it, `applyProfileScopedState`
    /// read those spaces as deleted-in-the-Spaces-tab and pruned
    /// them — snapping focus to the first space on every save.
    /// Staged edits stay authoritative: a space present in
    /// `seed` but removed from the model was deleted by the
    /// user this session and is not resurrected.
    public func mergeLiveSpaces(
        into config: inout GuiConfig,
        seededWith seed: [SpaceID]
    ) {
        var known = Set(seed)
        known.formUnion(config.spaces)
        for space in state.workspaces.allSpaces
        where !known.contains(space.id) {
            config.spaces.append(space.id)
            if space.mode != .bsp {
                config.spaceModes[space.id] = space.mode
            }
        }
    }

    /// The starter space set a fresh install gets — nine numbered
    /// spaces, so every digit key ⌃⌥1…9 binds out of the box even
    /// on a multi-monitor first run where more spaces are likely
    /// (#270). One constant behind both first-run pads (empty list
    /// and the single-space signature) so the count can't drift
    /// between them.
    static let starterSpaces = (1...9).map { SpaceID($0) }

    /// Builds an editable model from the running configuration.
    /// Keybindings and mode icons are recovered from the source
    /// file via `recoverKeybindings` (#4); the sidecar owns them
    /// once saved.
    func guiConfigSeed() -> GuiConfig {
        var config = GuiConfig()
        config.settings = tiler.settings
        config.appRules = globalAppRuleBase
        config.spacePins = spacePins
        config.mainSpaces = mainSpaces
        config.fallbackSpace = fallbackSpace
        config.modes = recoverKeybindings()
        config.floatRules = globalFloatRuleBase
        config.ignoreRules = globalIgnoreRuleBase
        var modes: [SpaceID: LayoutMode] = [:]
        var defined: [SpaceID] = []
        for space in state.workspaces.allSpaces {
            defined.append(space.id)
            if space.mode != .bsp { modes[space.id] = space.mode }
        }
        config.spaceModes = modes
        // De-dup only — live order is authoritative (#75).
        config.spaces = SpaceID.deduplicated(
            defined + Array(modes.keys)
        )
        if config.spaces.isEmpty {
            config.spaces = Self.starterSpaces
        }
        var bindings: [Int: String] = [:]
        for (number, name) in nativeSpaceBindings {
            bindings[number] = name
        }
        config.profileBindings = bindings
        seedDefaultShortcuts(&config)
        return config
    }

    /// First-run starter shortcuts (#91): when no mode carries
    /// a single binding — a fresh install, or an `init.lua`
    /// that declares none — the base `default` mode gets the
    /// starter set so a new user can drive KiwiDesk immediately.
    /// Also pads `config.spaces` on the bare first-run signature
    /// (see below) — a deliberate second effect, kept here rather
    /// than in `guiConfigSeed` because it depends on this same
    /// no-binding guard. Never fires once a user (or Lua) authored
    /// any binding, in any mode — idempotent by that guard, so the
    /// space padding is a first-run-only effect and never pollutes
    /// a Lua-managed user's space list.
    private func seedDefaultShortcuts(
        _ config: inout GuiConfig
    ) {
        guard
            config.modes.allSatisfy({ $0.bindings.isEmpty }),
            let index = config.modes.firstIndex(
                where: { $0.isDefault }
            )
        else { return }
        // First run reports only the ACTIVE Space (#270): the live
        // list is a single numbered space (usually ["1"]), which
        // would seed only ⌃⌥1. Pad just that bare signature to the
        // nine-space starter set the empty state already uses, so
        // ⌃⌥1…9 all work out of the box. A named or multi-space
        // list is a configured setup — left exactly as discovered
        // so the seed never invents spaces the user didn't (dedup
        // keeps the live space first, #75).
        if config.spaces.count == 1,
            Int(config.spaces[0].raw) != nil {
            config.spaces = SpaceID.deduplicated(
                config.spaces + Self.starterSpaces
            )
        }
        config.modes[index].bindings =
            DefaultKeybindings.bindings(
                spaces: config.spaces,
                resizeStep: Int(config.settings.resizeStep)
            )
    }
}
