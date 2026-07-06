import KiwiDeskCore

/// Upgrades imported `.custom` keybinding rows to `.navigation`
/// or `.application` by exact-matching the `KeybindingCatalog`, so
/// a recovered shortcut lands in the section that authored it with
/// its proper label. Only the GUI knows the catalog, so this runs
/// GUI-side after Core's `recoverKeybindings` (#4). Rows matching
/// nothing stay `.custom` and show in Custom Bindings.
enum KeybindingImportClassifier {
    /// Reclassifies every `.custom` row in `config` in place,
    /// rebuilding the navigation and change-mode commands the
    /// keybindings tab would generate from the config's own
    /// spaces and mode names.
    static func classify(_ config: inout GuiConfig) {
        let navigation = navigationLabels(for: config)
        for mode in config.modes.indices {
            for row in config.modes[mode].bindings.indices {
                reclassify(
                    &config.modes[mode].bindings[row],
                    navigation: navigation
                )
            }
        }
    }

    /// Lua action → label for every navigation and change-mode
    /// command the keybindings tab can produce for this config.
    private static func navigationLabels(
        for config: GuiConfig
    ) -> [String: String] {
        var map: [String: String] = [:]
        let groups = KeybindingCatalog.navigationGroups(
            spaces: config.spaces
        )
        for group in groups {
            for command in group.commands {
                map[command.lua] = command.label
            }
        }
        for name in config.modes.map(\.name) {
            let command = KeybindingCatalog.switchModeCommand(name)
            map[command.lua] = command.label
        }
        return map
    }

    private static func reclassify(
        _ binding: inout KeyBinding,
        navigation: [String: String]
    ) {
        guard binding.kind == .custom else { return }
        if let label = navigation[binding.lua] {
            binding.kind = .navigation
            binding.label = label
        } else if let app = KeybindingCatalog.appName(
            from: binding.lua
        ) {
            binding.kind = .application
            binding.label = app
        }
    }
}
