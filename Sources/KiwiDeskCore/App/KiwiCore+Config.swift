import Foundation

/// init.lua loading and declarative config globals.
extension KiwiCore {
    /// Loads (or reloads) init.lua into a fresh VM.
    public func loadConfig() {
        bus.resetLuaCallbacks()
        keys.reset()
        nativeSpaceBindings = [:]
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
        applyConfigGlobals(from: fresh)
        retile()
        // The current native space may carry a binding that
        // the config just (re)declared.
        applyNativeSpaceBinding()
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
        if case .table(let fallback) = lua.global(
            "monitor_fallback"
        ) {
            var mapped: [String: [String]] = [:]
            for (monitor, value) in fallback {
                if case .array(let chain) = value {
                    mapped[monitor] = chain.compactMap(
                        \.stringValue
                    )
                }
            }
            monitorFallback = mapped
        }
        if case .table(let map) = lua.global(
            "space_monitor_map"
        ) {
            var mapped: [SpaceID: [String]] = [:]
            for (space, value) in map {
                if case .array(let chain) = value {
                    mapped[SpaceID(space)] =
                        chain.compactMap(\.stringValue)
                }
            }
            spaceMonitorMap = mapped
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
