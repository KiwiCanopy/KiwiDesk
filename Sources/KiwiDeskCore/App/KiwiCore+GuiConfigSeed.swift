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

    /// Builds an editable model from the running configuration.
    /// Keybindings and mode icons are recovered from the source
    /// file via `recoverKeybindings` (#4); the sidecar owns them
    /// once saved.
    func guiConfigSeed() -> GuiConfig {
        var config = GuiConfig()
        config.settings = tiler.settings
        config.appRules = state.appRules
        config.spacePins = spacePins
        config.mainSpaces = mainSpaces
        config.fallbackSpace = fallbackSpace
        config.modes = recoverKeybindings()
        config.floatRules = eventLoop.floatRules.rawRules
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
            config.spaces = (1...5).map { SpaceID($0) }
        }
        var bindings: [Int: String] = [:]
        for (number, name) in nativeSpaceBindings {
            bindings[number] = name
        }
        config.profileBindings = bindings
        return config
    }
}
