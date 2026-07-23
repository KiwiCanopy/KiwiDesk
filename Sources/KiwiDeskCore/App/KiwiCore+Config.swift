import Foundation

/// init.lua loading and declarative config globals.
extension KiwiCore {
    /// Loads (or reloads) init.lua into a fresh VM.
    public func loadConfig() {
        keybindingRuntimeGeneration &+= 1
        bus.resetLuaCallbacks()
        appliedStructuredModes = nil
        keys.reset()
        nativeSpaceBindings = [:]
        resetDeclarativeState()
        defersWindowRuleReconcile = true
        defer { defersWindowRuleReconcile = false }
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

        // Seed a default gui.json so the boot is GUI-managed with
        // the default profile, spaces, and shortcuts (#91) —
        // without a sidecar the structured loader is a no-op and a
        // fresh install would boot with zero shortcuts. This also
        // covers an init.lua that carries only harmless custom Lua
        // (e.g. sketchybar event hooks): it declares no managed
        // settings, so it should still get the GUI defaults and
        // keep firing its hooks, rather than booting to a bare
        // single space (#354). Skip only when init.lua declares
        // managed settings of its own (Lua-owned until adopted —
        // seeding would let the GUI defaults override the user's
        // Lua settings) or a sidecar already exists. Read the
        // user's file *before* ensureDefaultConfig writes the
        // all-comment starter template (which declares nothing).
        let luaOwnsSettings = configDeclaresManagedSettings
        ensureDefaultConfig()
        // No sidecar yet and no Lua-owned settings: seed gui.json
        // (space list + scaled shortcuts). Unchanged from before —
        // this also re-seeds on a reload of a Lua config that has
        // no gui.json, which is harmless.
        let seedGuiConfig = !guiConfigStore.exists && !luaOwnsSettings
        if seedGuiConfig {
            try? guiConfigStore.save(guiConfigSeed())
        }
        // The beginner ladder's profile-scoped half is materialized
        // (once displays are known, below) only on a TRULY fresh
        // install — no profile of any kind exists yet — so a Lua
        // config that already saved a profile keeps it and is never
        // handed a Starter profile (#466).
        let seedStarterProfile =
            seedGuiConfig && profiles.list().isEmpty
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
        // Lua declarations are only the global base. Put the
        // active profile's tiling and sparse behavior overrides
        // back on top before the native-Space binding gets the
        // final say below.
        reapplyActiveProfileState()
        // The current native space may carry a binding that
        // the config just (re)declared. Window-rule reconcile
        // stays deferred until this final profile wins.
        applyNativeSpaceBinding()
        defersWindowRuleReconcile = false
        // The rule owner/profile just changed: re-sync every app
        // once against the FINAL effective rules. Without this,
        // verdicts stay stale until an unrelated AX event (#164).
        eventLoop.reconcileAll()
        // Author the beginner ladder's "Starter" profile (modes,
        // pins, tuning). It reads displays from NSScreen itself
        // (the event loop hasn't published them yet) and runs
        // before the loop's first monitor change, which then
        // matches and keeps it (#466). First-run-only.
        if seedStarterProfile {
            seedFirstRunStarterProfile()
        }
        retile()
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
        eventLoop.ignoreRules = IgnoreRules([])
        globalAppRuleBase = [:]
        globalFloatRuleBase = []
        globalIgnoreRuleBase = []
        tiler.settings.gapsOverride = [:]
        tiler.settings.placementOverride = [:]
        tiler.settings.spaceIcons = [:]
        fallbackSpace = nil
        // The session resize layer reseeds on reload (#458):
        // the config about to apply is the new truth, and a
        // shadowing session value would make an edited ratio
        // visibly do nothing (§5 forced-retile rationale).
        clearSessionRatios { $0 = SessionRatios() }
        for space in state.workspaces.allSpaces
        where space.mode != .bsp {
            setSpaceMode(space.id, .bsp)
        }
    }

    /// Applies declarative globals after the config ran.
    private func applyConfigGlobals(from lua: LuaInterpreter) {
        if case .array(let rules) = lua.global("float_rules") {
            eventLoop.floatRules = FloatRules(
                rules.compactMap(\.stringValue)
            )
        }
        if case .array(let rules) = lua.global("ignore_rules") {
            eventLoop.ignoreRules = IgnoreRules(
                rules.compactMap(\.stringValue)
            )
        }
        if case .table(let rules) = lua.global("app_rules") {
            var mapped: [String: SpaceID] = [:]
            for (app, value) in rules {
                if let space = value.stringValue {
                    // Keyed by bundle id, lower-cased to match
                    // the normalized `ManagedWindow.appBundleID`
                    // (case-insensitive, like LaunchServices).
                    mapped[app.lowercased()] = SpaceID(space)
                }
            }
            state.appRules = mapped
        }
        captureGlobalWindowRuleBase(
            appRules: state.appRules,
            floatRules: eventLoop.floatRules.rawRules,
            ignoreRules: eventLoop.ignoreRules.rawRules
        )
    }

    /// Writes a starter init.lua on first launch.
    /// Whether `init.lua` declares any managed *setting* (the
    /// `KiwiDesk.set_*` verbs plus the rule/bind/mode tokens) —
    /// gates the first-launch `gui.json` seed above so a Lua-owned
    /// settings config is never seeded over (#354). Absent file or
    /// a hooks-only file → `false`.
    var configDeclaresManagedSettings: Bool {
        guard
            let source = try? String(
                contentsOf: configURL,
                encoding: .utf8
            )
        else { return false }
        return ManagedConfig.declaresManagedSettings(source)
    }

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
            -- float_rules = { "com.apple.calculator" }

            -- Apps KiwiDesk should never manage at all:
            -- ignore_rules = { "eu.exelban.Stats" }

            -- Send apps to fixed spaces:
            -- app_rules = {
            --   ["com.spotify.client"] = "music"
            -- }

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
