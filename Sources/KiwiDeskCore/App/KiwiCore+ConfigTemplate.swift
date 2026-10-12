import Foundation

/// The first-launch `init.lua` and the seed gate that reads it.
extension KiwiCore {
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

    func ensureDefaultConfig() {
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
            -- Docs: https://github.com/KiwiCanopy/KiwiDesk
            --
            -- Everyday settings live in the Settings window;
            -- this file is for optional custom Lua. Comments
            -- only by default — the built-in defaults apply
            -- until a line below is uncommented.

            -- One value for all gaps (the built-in default):
            -- KiwiDesk.set_gap_global(10)

            -- Every Space has its own layout; the first
            -- argument is the SPACE id (number or name),
            -- never a monitor. All Spaces
            -- default to "bsp". Modes: bsp | stack |
            -- scrolling | monocle | grid | floating
            -- KiwiDesk.set_mode(1, "stack")
            -- KiwiDesk.set_mode("music", "floating")

            -- Windows that should never be tiled:
            -- float_rules = { "com.apple.calculator" }

            -- Apps KiwiDesk should never manage at all:
            -- ignore_rules = { "eu.exelban.Stats" }

            -- Send apps to fixed Spaces:
            -- app_rules = {
            --   ["com.spotify.client"] = "music"
            -- }

            -- Load a saved profile per macOS Desktop
            -- (the Mission Control number):
            -- KiwiDesk.bind_profile_to_desktop(
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
