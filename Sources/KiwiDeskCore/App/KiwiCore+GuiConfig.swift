import Foundation

/// The GUI dashboard's read/write bridge to the running core.
///
/// Reading: the dashboard opens the `gui.json` sidecar when it
/// exists, else seeds an editable model from live state. Any
/// hand-written Lua touching managed vocabulary flips the
/// editor into raw-Lua fallback (`configHasForeignCode`).
///
/// Writing: the model is persisted to the sidecar and the
/// config reloaded — the structured loader applies it directly
/// (#55). `init.lua` is never touched by a save: it is
/// hooks-only, owned by the user.
extension KiwiCore {
    public var guiConfigStore: GuiConfigStore {
        GuiConfigStore(directory: configDirectory)
    }

    /// The base keybinding modes every profile override
    /// resolves onto AND diffs against — the ONE definition
    /// shared by the resolve side (`loadGuiConfig(editing:)`),
    /// the diff side (`overwriteProfile`, which inlines it to
    /// reuse a single sidecar decode), and the GUI's
    /// override-mode baseline (#55). Sidecar modes when the
    /// sidecar decodes; the live seed otherwise. Asymmetric
    /// bases would mint spurious overrides (e.g. the whole
    /// recovered set diffed against []). The seed branch is
    /// time-dependent (recovers from the live VM) — callers
    /// should read it once per edit/save cycle, not cache it
    /// across reloads.
    public func baseKeyModes() -> [KeyMode] {
        (guiConfigStore.load() ?? guiConfigSeed()).modes
    }

    /// The authored gui.json config WITHOUT `loadGuiConfig()`'s
    /// live-profile overlay — the persisted shape as written. The
    /// read-only shortcuts panel reads this while window management
    /// is paused (#326): the live overlay carries an empty space
    /// list when the engine hasn't discovered spaces, which would
    /// misfile space shortcuts. nil when no sidecar exists.
    public func persistedGuiConfig() -> GuiConfig? {
        guiConfigStore.load()
    }

    /// The base app→space rules every profile override
    /// resolves onto AND diffs against — `baseKeyModes()`'s
    /// app-rule sibling (#109), with the same one-definition
    /// and read-once-per-cycle caveats.
    public func baseAppRules() -> [String: SpaceID] {
        guard isGuiManaged else { return globalAppRuleBase }
        guard let rules = guiConfigStore.load()?.appRules else {
            return globalAppRuleBase
        }
        return AppRuleOverride.normalized(rules)
    }

    /// Global float-rule base for the stored-profile editor.
    public func baseFloatRules() -> [String] {
        guard isGuiManaged else { return globalFloatRuleBase }
        guard let rules = guiConfigStore.load()?.floatRules else {
            return globalFloatRuleBase
        }
        return FloatRules(rules).rawRules
    }

    /// Global ignore-rule base. The GUI has no ignore editor yet,
    /// but stored-profile loads resolve it for preservation parity.
    public func baseIgnoreRules() -> [String] {
        guard isGuiManaged else { return globalIgnoreRuleBase }
        guard let rules = guiConfigStore.load()?.ignoreRules else {
            return globalIgnoreRuleBase
        }
        return IgnoreRules(rules).rawRules
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
        config.appRules = baseAppRules()
        config.floatRules = baseFloatRules()
        config.ignoreRules = baseIgnoreRules()
        overlayProfileState(&config, from: profile)
        return config
    }

    /// Applies the model's profile-scoped state to the running
    /// core (settings, modes, pins, Main role) and re-resolves
    /// placement — the in-memory half of a profile save; the
    /// caller persists via `persistProfile(named:)`.
    public func applyProfileScopedState(
        from config: GuiConfig
    ) {
        // The engine's cached durations sync via
        // `TilingEngine.settings.didSet`, so the retile below
        // animates at the incoming duration, not a stale one
        // (#51 review).
        tiler.settings = config.settings
        // Ensure spaces in display order first (config.spaces
        // is the authoritative list, so insertion order matches
        // the user's chosen Spaces ordering). Any extras that
        // appear only in modes/pins/main get appended after.
        let inList = Set(config.spaces)
        var extra: Set<SpaceID> = []
        extra.formUnion(config.spaceModes.keys)
        extra.formUnion(config.spacePins.keys)
        extra.formUnion(config.mainSpaces)
        for space in config.spaces {
            state.workspaces.ensureSpace(space)
        }
        for space in extra.subtracting(inList) {
            state.workspaces.ensureSpace(space)
        }
        // `ensureSpace` early-returns for existing spaces, so
        // reconcile the live order to the GUI's display order:
        // a later live save (`buildProfile`) then captures the
        // same order `overwriteProfile` would — one order
        // representation across both save paths (#75/#55).
        state.workspaces.reorder(matching: config.spaces)
        // A space the model no longer references anywhere (list,
        // modes, pins, Main) was deleted in the Spaces tab — drop
        // it from live too, forwarding any windows, or the next
        // `buildProfile` would recapture it and it would reappear
        // on reload (#77). Same reconcile as an explicit
        // `load_profile`; survivors are exactly the set ensured
        // above, so the just-added extras are never pruned. The
        // sidecar half is closed by the caller — `persist`
        // rewrites gui.json when the space list changed
        // (`globalsChanged`) — so the cold-boot seed can't re-add
        // the dropped space; this path needs no direct mirror.
        pruneSpaces(
            keeping: inList.union(extra),
            orderedBy: config.spaces,
            preferring: config.fallbackSpace
        )
        for space in state.workspaces.allSpaces {
            state.workspaces.setMode(
                space.id,
                config.spaceModes[space.id] ?? .bsp
            )
        }
        spacePins = config.spacePins
        mainSpaces = config.mainSpaces
        // A fallback pointing outside the edited space list is
        // meaningless — drop it rather than persist a dangling
        // reference (#68).
        fallbackSpace = config.fallbackSpace.flatMap {
            config.spaces.contains($0) ? $0 : nil
        }
        resolveSpaceDisplays()
        // Forced: this is an explicit settings apply, not an
        // AX-echo-driven refresh. Un-forced, the engine's
        // "already there" tolerance (±2 pt/edge) swallows
        // small edits — a 1 pt gap change moved every window
        // by ≤2 pt and visibly did nothing (#68).
        retile(force: true)
        emitSpaceChange()
    }

    /// Cold-boot story for GUI-only spaces (#77): seeds live from
    /// the sidecar's `spaces` list so a space that lives *only* in
    /// `gui.json` — no active profile, pin, window, or Lua
    /// `set_mode` backs it — is present in live and survives the
    /// next reload (`overlayLiveProfileState` reads live, not the
    /// sidecar). Runs in `loadConfig` before the first
    /// `handleMonitorChange` adopts a profile, which then ensures
    /// its own spaces on top. Only *adds* (never sets modes or
    /// removes), so a Lua-declared space keeps its mode and no
    /// live-only space is dropped. Safe against resurrecting a
    /// profile-pruned space because every authoritative prune
    /// mirrors live back into the sidecar (`syncGuiSpacesToLive`),
    /// so its `spaces` list is never stale.
    func seedGuiSpaces() {
        guard let config = guiConfigStore.load() else { return }
        for space in config.spaces {
            state.workspaces.ensureSpace(space)
        }
        state.workspaces.reorder(matching: config.spaces)
    }

    /// Mirrors the live space set back into `gui.json` after an
    /// authoritative reconcile changed it (a `load_profile` or an
    /// in-effect edit that pruned stale spaces), keeping the
    /// sidecar a faithful copy of live so the cold-boot seed above
    /// never re-injects a space a profile load dropped (#77).
    /// GUI-managed only (no sidecar otherwise); writes the store
    /// directly — NOT `saveGuiConfig`, which would reload the
    /// config mid-command. A no-op when the list already matches.
    func syncGuiSpacesToLive() {
        guard isGuiManaged, var config = guiConfigStore.load()
        else { return }
        let live = SpaceID.deduplicated(
            state.workspaces.allSpaces.map(\.id)
        )
        guard config.spaces != live else { return }
        config.spaces = live
        try? guiConfigStore.save(config)
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
    /// then reloads — the structured loader registers rules and
    /// keybindings directly from the sidecar (#55). `init.lua`
    /// is not touched.
    public func saveGuiConfig(_ config: GuiConfig) throws {
        try guiConfigStore.save(config)
        loadConfig()
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
    /// current file is preserved verbatim as a commented backup
    /// (no managed block is generated — the seeded `gui.json`
    /// now owns rules and keybindings, #55). Gaps, layouts,
    /// rules, and keybindings carry over from the live
    /// (executed) state — bindings are recovered from the file
    /// via `recoverKeybindings`; any that can't be read back
    /// stay only in the backup. Returns the seeded model now
    /// under GUI ownership.
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
}
