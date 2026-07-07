import Foundation

/// init.lua loading and declarative config globals.
extension KiwiCore {
    /// Loads (or reloads) init.lua into a fresh VM.
    public func loadConfig() {
        bus.resetLuaCallbacks()
        keys.reset()
        nativeSpaceBindings = [:]
        resetDeclarativeState()
        guard let fresh = LuaInterpreter() else {
            onLog("failed to create Lua VM")
            return
        }
        lua = fresh
        bus.lua = fresh
        keys.lua = fresh
        registerLuaAPI(on: fresh)

        ensureDefaultConfig()
        if case .failure(let error) = fresh.runFile(
            configURL
        ) {
            onLog("init.lua error: \(error)")
        }
        // Two mutually exclusive config owners (#55, O7):
        // GUI-managed configs load rules + keybindings directly
        // from gui.json via the structured loader; hand-written
        // (or foreign-Lua) configs keep their Lua-declared
        // globals via applyConfigGlobals. A stale managed block
        // from an earlier version still executes its binds —
        // the structured reset makes them inert (O6).
        // Keybindings resolve against the profile active NOW;
        // a profile applied later (e.g. applyNativeSpaceBinding
        // below) re-registers in phase 6 (#55).
        if isGuiManaged {
            applyStructuredConfig()
        } else {
            applyConfigGlobals(from: fresh)
        }
        retile()
        // Lua-declared tiling is only the base state: the
        // active profile (or transient Standard) owns tiling
        // and goes back on top after a reload (#36).
        reapplyActiveProfileState()
        // The current native space may carry a binding that
        // the config just (re)declared.
        applyNativeSpaceBinding()
    }

    /// Clears every setting the config declares *sparsely* so a
    /// reload is authoritative, not additive: the writer omits
    /// deleted entries (removed app/float rules, gap or
    /// placement overrides, a space reverted to `bsp`), and
    /// without this reset the stale live value would survive.
    /// Fully-emitted settings (global gaps, min size, per-layout
    /// params) are always overwritten, so they need no reset.
    private func resetDeclarativeState() {
        state.appRules = [:]
        eventLoop.floatRules = FloatRules([])
        tiler.settings.gapsOverride = [:]
        tiler.settings.placementOverride = [:]
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

            KiwiDesk.set_gap_global(10)

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
