import Foundation

/// The GUI dashboard's read/write bridge to the running core.
///
/// Reading: the dashboard opens the `gui.json` sidecar when it
/// exists, else seeds an editable model from live state. Any
/// hand-written Lua outside the managed block flips the editor
/// into raw-Lua fallback (`configHasForeignCode`).
///
/// Writing: the model is persisted to the sidecar and its
/// managed block spliced into `init.lua`, then the config is
/// reloaded so the change takes effect immediately.
extension KiwiCore {
    public var guiConfigStore: GuiConfigStore {
        GuiConfigStore(directory: configDirectory)
    }

    /// The editable model for the dashboard: the saved sidecar
    /// if present, otherwise a snapshot of live state. The
    /// sidecar only persists the global fields; the
    /// profile-scoped ones (tiling, modes, pins) are overlaid
    /// from live state, whose source of truth is the active
    /// profile (#36).
    public func loadGuiConfig() -> GuiConfig {
        guard var config = guiConfigStore.load() else {
            return guiConfigSeed()
        }
        overlayLiveProfileState(&config)
        return config
    }

    /// The editable model for **a stored profile**, not the live
    /// one (#18): global fields come from the sidecar/live seed
    /// exactly as `loadGuiConfig()`, but the profile-scoped
    /// fields are overlaid from `name`'s JSON instead of live
    /// state — so the dashboard can edit a saved profile without
    /// switching the running layout. Throws if the profile is
    /// unreadable (the caller falls back to live editing).
    public func loadGuiConfig(
        editing name: String
    ) throws -> GuiConfig {
        let profile = try profiles.read(name: name)
        var config = guiConfigStore.load() ?? guiConfigSeed()
        overlayProfileState(&config, from: profile)
        return config
    }

    /// Copies a *stored* profile's tiling into the model —
    /// sibling of `overlayLiveProfileState`, reading the profile
    /// instead of live state. Pins come from the set covering the
    /// connected monitors (empty when none matches, i.e. the
    /// Canvas can't be edited for this profile right now).
    private func overlayProfileState(
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
    }

    /// Copies the live profile-scoped state into the model:
    /// tiling settings, per-space modes, monitor pins, and the
    /// Main role.
    private func overlayLiveProfileState(
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
        // Live state is authoritative for which spaces EXIST (#75).
        // Order: use the sidecar's stored list as the base (keeps
        // the user's chosen display order across reloads), filter
        // to live members, then append any live space absent from
        // the sidecar. Stale sidecar spaces (no longer live after a
        // profile-load prune) drop via the filter. A bare space
        // only in `gui.json` drops too — it wasn't seeded at boot.
        let liveSet = Set(live)
        let ordered = config.spaces.filter { liveSet.contains($0) }
        let inOrdered = Set(config.spaces)
        let extra = live.filter { !inOrdered.contains($0) }
        config.spaces = GuiConfig.deduplicated(ordered + extra)
        config.spacePins = spacePins
        config.mainSpaces = mainSpaces
    }

    /// Applies the model's profile-scoped state to the running
    /// core (settings, modes, pins, Main role) and re-resolves
    /// placement — the in-memory half of a profile save; the
    /// caller persists via `persistProfile(named:)`.
    public func applyProfileScopedState(
        from config: GuiConfig
    ) {
        tiler.settings = config.settings
        var known = Set(config.spaces)
        known.formUnion(config.spaceModes.keys)
        known.formUnion(config.spacePins.keys)
        known.formUnion(config.mainSpaces)
        for space in known {
            state.workspaces.ensureSpace(space)
        }
        for space in state.workspaces.allSpaces {
            state.workspaces.setMode(
                space.id,
                config.spaceModes[space.id] ?? .bsp
            )
        }
        spacePins = config.spacePins
        mainSpaces = config.mainSpaces
        resolveSpaceDisplays()
        retile()
        emitSpaceChange()
    }

    /// Whether the GUI owns the configuration — the ownership
    /// discriminator for the three tiling tiers (#36): only a
    /// GUI-managed config lets the composed Standard own
    /// tiling on an unmatched monitor change; hand-written or
    /// hybrid configs (foreign Lua beside the managed block)
    /// keep their Lua-declared tiling and get placement-only
    /// resolution. Mirrors the editor, which demotes itself to
    /// the raw-Lua fallback on foreign code.
    public var isGuiManaged: Bool {
        guiConfigStore.exists && !configHasForeignCode
    }

    /// Whether `init.lua` holds code outside the managed block
    /// that touches the managed vocabulary — verbs the GUI
    /// itself generates. When true the visual editor cannot
    /// safely co-own the file and falls back to raw Lua mode.
    /// Harmless custom Lua (e.g. `print`, sketchybar hooks)
    /// does NOT set this; use `configHasCustomCode` for the
    /// informational banner.
    public var configHasForeignCode: Bool {
        guard
            let source = try? String(
                contentsOf: configURL,
                encoding: .utf8
            )
        else { return false }
        return ManagedConfig.hasForeignCode(source)
    }

    /// Whether `init.lua` holds any non-blank, non-comment Lua
    /// outside the managed block (including harmless code that
    /// does not touch managed vocabulary). Used to show the
    /// "you also have custom Lua" banner in the visual editor.
    /// Always `false` when `configHasForeignCode` is `true`
    /// (the raw editor is shown instead of the banner).
    public var configHasCustomCode: Bool {
        guard
            let source = try? String(
                contentsOf: configURL,
                encoding: .utf8
            )
        else { return false }
        return ManagedConfig.hasCustomCode(source)
    }

    /// Persists the model and applies it: writes `gui.json`,
    /// regenerates `init.lua`'s managed block, then reloads.
    public func saveGuiConfig(_ config: GuiConfig) throws {
        try guiConfigStore.save(config)
        try writeManagedBlock(for: config)
        loadConfig()
    }

    /// Splices a freshly generated managed block into the
    /// existing `init.lua`, preserving surrounding user code.
    private func writeManagedBlock(
        for config: GuiConfig
    ) throws {
        let existing =
            (try? String(
                contentsOf: configURL,
                encoding: .utf8
            )) ?? ""
        let block = LuaConfigWriter.block(for: config)
        let merged = ManagedConfig.merge(
            block: block,
            into: existing
        )
        try FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true
        )
        try merged.write(
            to: configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    /// Recovers the live keybindings as editable modes (#4): each
    /// bound combo plus its action text, sliced from the source
    /// file via `debug.getinfo`. Rows come back as `.custom`; the
    /// GUI classifies known catalog actions afterwards. Returns at
    /// least the default mode (empty when nothing is bound or the
    /// interpreter is unavailable).
    public func recoverKeybindings() -> [KeyMode] {
        guard let lua else { return [KeyMode.defaultMode] }
        return KeybindingImporter.modes(
            from: keys,
            interpreter: lua,
            readFile: { path in
                try? String(
                    contentsOfFile: path,
                    encoding: .utf8
                )
            }
        )
    }

    /// Migrates a hand-written config into GUI management: the
    /// current file is preserved verbatim as a commented backup,
    /// and a fresh managed block is generated from the live
    /// (executed) state — gaps, layouts, rules, and keybindings
    /// carry over (bindings are recovered from the file via
    /// `recoverKeybindings`; any that can't be read back stay
    /// only in the backup). Returns the seeded model now under
    /// GUI ownership.
    @discardableResult
    public func adoptConfigIntoGui() throws -> GuiConfig {
        let original =
            (try? String(
                contentsOf: configURL,
                encoding: .utf8
            )) ?? ""
        let config = guiConfigSeed()
        try guiConfigStore.save(config)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let file = ManagedConfig.adopt(
            original: original,
            block: LuaConfigWriter.block(for: config),
            date: formatter.string(from: .now)
        )
        try FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true
        )
        try file.write(
            to: configURL,
            atomically: true,
            encoding: .utf8
        )
        loadConfig()
        // The reload reset the sparse tiling state and the
        // managed block no longer re-declares it (#36); put the
        // executed original's tiling back so adopt preserves
        // the live arrangement until it is saved as a profile.
        applyProfileScopedState(from: config)
        return config
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
        config.spaces = GuiConfig.deduplicated(
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
