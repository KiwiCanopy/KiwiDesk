import CoreGraphics
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
    /// `recoverResizeStep` reads a recovered Grow/Shrink magnitude
    /// back into `resize.step` (#58) — pass it ONLY on an explicit
    /// import, where the pulled-in bindings are the source of
    /// truth. A plain load-for-edit leaves it `false`: there
    /// `resize.step` is already authoritative (from tiler/profile
    /// settings), so a magnitude baked into a stray `.custom` row
    /// must not overwrite it (#58 review).
    static func classify(
        _ config: inout GuiConfig,
        recoverResizeStep: Bool = false
    ) {
        let navigation = navigationLabels(for: config)
        var recoveredStep: Int?
        for mode in config.modes.indices {
            for row in config.modes[mode].bindings.indices {
                if let step = reclassify(
                    &config.modes[mode].bindings[row],
                    navigation: navigation
                ) {
                    recoveredStep = step
                }
            }
        }
        // Grow and Shrink carry the same magnitude, so the last
        // recovered row wins harmlessly; untouched when the import
        // has no resize row (keeps the default).
        if recoverResizeStep, let recoveredStep {
            config.settings.resizeStep = CGFloat(recoveredStep)
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
        // Step-independent Size & Float row: not in any
        // navigation group and matched by no shape rule, so it
        // needs its own entry or an imported `make_floating()`
        // stays Custom (#91).
        let float = KeybindingCatalog.makeFloating
        map[float.lua] = float.label
        return map
    }

    /// Reclassifies one `.custom` row, returning a recovered
    /// Grow/Shrink magnitude when the row is a resize of any step
    /// (so `classify` can read it back into `resize.step`, #58).
    /// Resize is checked first — before the exact-match map — so
    /// a magnitude differing from the current step still upgrades
    /// out of Custom.
    @discardableResult
    private static func reclassify(
        _ binding: inout KeyBinding,
        navigation: [String: String]
    ) -> Int? {
        guard binding.kind == .custom else { return nil }
        if let shape = KeybindingCatalog.resizeShape(
            from: binding.lua
        ) {
            binding.kind = .navigation
            binding.label = shape.label
            return shape.step
        }
        if let label = navigation[binding.lua] {
            binding.kind = .navigation
            binding.label = label
        } else if let app = KeybindingCatalog.appName(
            from: binding.lua
        ) {
            binding.kind = .application
            binding.label = app
        }
        return nil
    }
}
