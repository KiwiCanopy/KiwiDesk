import Foundation

/// init.lua loading and declarative config globals.
extension KiwiCore {
    /// Loads (or reloads) init.lua into a fresh VM.
    public func loadConfig() {
        bus.resetLuaCallbacks()
        keys.reset()
        nativeSpaceBindings = [:]
        resetDeclarativeState()
        var issues: [ConfigIssue] = []
        guard let fresh = LuaInterpreter() else {
            onLog("failed to create Lua VM")
            // The panel must stay complete even when the
            // config system is at its most broken: report the
            // sidecar and profile problems alongside the VM
            // failure.
            issues.append(
                ConfigIssue(
                    source: "init.lua",
                    message: "failed to create the Lua VM"
                )
            )
            if guiConfigStore.exists,
                guiConfigStore.load() == nil
            {
                issues.append(unreadableSidecarIssue)
            }
            configLoadIssues = issues
            refreshConfigIssues()
            return
        }
        lua = fresh
        bus.lua = fresh
        keys.lua = fresh
        registerLuaAPI(on: fresh)

        // True first launch: no init.lua yet (the starter
        // template is written just below). Persist the seeded
        // model — including the default shortcuts (#91) — so
        // the very first boot is GUI-managed and registers a
        // usable shortcut set; without a sidecar the
        // structured loader is a no-op and a fresh install
        // would boot with zero shortcuts. Never fires when an
        // init.lua already exists (that config is Lua-owned
        // until adopted) or when a sidecar is present.
        let firstLaunch = !FileManager.default.fileExists(
            atPath: configURL.path
        )
        ensureDefaultConfig()
        if firstLaunch, !guiConfigStore.exists {
            try? guiConfigStore.save(guiConfigSeed())
        }
        // Typo-guard hits are recorded only for the chunk run:
        // a guarded unknown call is non-fatal, so it must land
        // here as an issue to stay visible (#39).
        let typos = recordingTypoIssues {
            if case .failure(let error) = fresh.runFile(
                configURL
            ) {
                onLog("init.lua error: \(error)")
                issues.append(
                    ConfigIssue(
                        source: "init.lua",
                        message: "\(error)"
                    )
                )
            }
        }
        issues.append(contentsOf: typos)
        // A sidecar that exists but no longer decodes means
        // the visual editor (and the structured loader) can't
        // see the user's rules — half-loaded, must be visible.
        if guiConfigStore.exists, guiConfigStore.load() == nil {
            issues.append(unreadableSidecarIssue)
        }
        // Two mutually exclusive config owners (#55, O7):
        // GUI-managed configs load rules + keybindings directly
        // from gui.json via the structured loader; hand-written
        // (or foreign-Lua) configs keep their Lua-declared
        // globals via applyConfigGlobals. A stale managed block
        // from an earlier version still executes its binds —
        // the structured reset makes them inert (O6).
        // Keybindings resolve against the profile active NOW;
        // a profile applied later (reapplyActiveProfileState /
        // applyNativeSpaceBinding below) re-registers with its
        // own override via apply(profile:) (#55 phase 6).
        if isGuiManaged {
            applyStructuredConfig()
            // Seed GUI-only spaces before the active profile
            // (below) or a monitor change ensures its own on
            // top — a bare sidecar space would otherwise never
            // enter live and would drop on reload (#77).
            seedGuiSpaces()
        } else {
            applyConfigGlobals(from: fresh)
        }
        // The float rules just changed hands: re-sync every
        // app so `detectedFloating` reflects the NEW rules.
        // Without this, verdicts stay stale until an unrelated
        // AX event — user-visible since `make_auto` (#164)
        // re-applies the cached verdict, and a rule edit +
        // reload + make_auto would restore the pre-edit state.
        // recheckFloat only emits on changed verdicts, so an
        // unchanged config costs one quiet pass. No-op before
        // the event loop starts (startup load: no observers).
        eventLoop.reconcileAll()
        retile()
        // Lua-declared tiling is only the base state: the
        // active profile (or transient Standard) owns tiling
        // and goes back on top after a reload (#36).
        reapplyActiveProfileState()
        // The current native space may carry a binding that
        // the config just (re)declared.
        applyNativeSpaceBinding()
        // Publish what this load could not apply (#68): the
        // Lua/sidecar problems above plus any profile JSON
        // that no longer decodes.
        configLoadIssues = issues
        refreshConfigIssues()
    }

    private var unreadableSidecarIssue: ConfigIssue {
        ConfigIssue(
            source: "gui.json",
            message: "unreadable — rules and "
                + "shortcuts were not applied"
        )
    }

    /// Clears every setting the config declares *sparsely* so a
    /// reload is authoritative, not additive: the writer omits
    /// deleted entries (removed app/float rules, gap or
    /// placement overrides, a space reverted to `bsp`, a
    /// cleared space icon or fallback space), and without this
    /// reset the stale live value would survive.
    /// Fully-emitted settings (global gaps, min size, per-layout
    /// params) are always overwritten, so they need no reset.
    private func resetDeclarativeState() {
        state.appRules = [:]
        eventLoop.floatRules = FloatRules([])
        tiler.settings.gapsOverride = [:]
        tiler.settings.placementOverride = [:]
        tiler.settings.spaceIcons = [:]
        fallbackSpace = nil
        for space in state.workspaces.allSpaces
        where space.mode != .bsp {
            state.workspaces.setMode(space.id, .bsp)
        }
    }

    /// Applies declarative globals after the config ran.
    private func applyConfigGlobals(from lua: LuaInterpreter) {
        if case .array(let rules) = lua.global("float_rules") {
            eventLoop.floatRules = FloatRules(
                rules.compactMap(\.stringValue)
            )
        }
        if case .table(let rules) = lua.global("app_rules") {
            var mapped: [String: SpaceID] = [:]
            for (app, value) in rules {
                if let space = value.stringValue {
                    mapped[app] = SpaceID(space)
                }
            }
            state.appRules = mapped
        }
    }

    /// Writes a starter init.lua on first launch.
    private func ensureDefaultConfig() {
        let files = FileManager.default
        guard !files.fileExists(atPath: configURL.path) else {
            return
        }
        try? files.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true
        )
        let template = """
            -- KiwiDesk configuration
            -- Docs: https://github.com/hajiboy95/KiwiDesk
            --
            -- Everyday settings live in the Settings window;
            -- this file is for optional custom Lua. Comments
            -- only by default — the built-in defaults apply
            -- until a line below is uncommented.

            -- One value for all gaps (the built-in default):
            -- KiwiDesk.set_gap_global(10)

            -- Every virtual space (workspace) has its own
            -- layout; the first argument is the SPACE id
            -- (number or name), never a monitor. All spaces
            -- default to "bsp". Modes: bsp | stack |
            -- scrolling | monocle | grid | floating
            -- KiwiDesk.set_mode(1, "stack")
            -- KiwiDesk.set_mode("music", "floating")

            -- Windows that should never be tiled:
            -- float_rules = { "Calculator", "Finder:Get Info" }

            -- Send apps to fixed spaces:
            -- app_rules = { ["Spotify"] = "music" }

            -- Load a saved profile per native macOS Space
            -- (the Mission Control desktop number):
            -- KiwiDesk.bind_profile_to_native_space(
            --     2, "Creator Studio")

            -- Keybindings:
            -- KiwiDesk.bind("cmd+alt+left", function()
            --     KiwiDesk.focus("left")
            -- end)
            """
        try? template.write(
            to: configURL,
            atomically: true,
            encoding: .utf8
        )
    }
}
