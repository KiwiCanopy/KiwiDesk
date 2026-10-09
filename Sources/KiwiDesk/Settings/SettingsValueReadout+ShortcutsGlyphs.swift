import CoreFoundation
import KiwiDeskCore

/// Shortcut action label resolution and glyph rendering for settings readout
/// (#23).
extension SettingsValueReadout {
    /// Localized action labels keyed by Lua, from the one roster
    /// (`KeybindingCatalog.namedCommands`) over the union of BOTH
    /// sides' spaces, layers, resize steps and bindings, so a row
    /// keeps its name even when the draft renamed what it targets.
    static func shortcutsActionLabels(
        old: GuiConfig,
        new: GuiConfig
    ) -> [String: String] {
        var spaces: [SpaceID] = []
        for space in old.spaces + new.spaces
        where !spaces.contains(space) {
            spaces.append(space)
        }
        var layerNames: [String] = []
        for layer in old.layers + new.layers
        where !layerNames.contains(layer.name) {
            layerNames.append(layer.name)
        }
        let steps = Set([
            Int(old.settings.resizeStep),
            Int(new.settings.resizeStep),
        ])
        let commands = KeybindingCatalog.namedCommands(
            spaces: spaces,
            layerNames: layerNames,
            steps: steps.sorted(),
            bindings: (old.layers + new.layers).flatMap(\.bindings)
        )
        var labels: [String: String] = [:]
        for command in commands
        where labels[command.lua] == nil {
            labels[command.lua] = command.resolvedLabel
        }
        return labels
    }

    /// Resolves display label for keybinding.
    static func shortcutsBindingLabel(
        _ binding: KeyBinding,
        labels: [String: String],
        config: GuiConfig
    ) -> String {
        if let label = labels[binding.lua] { return label }
        if binding.kind == .application,
            let bundleID = KeybindingCatalog.appBundleID(
                from: binding.lua
            )
        {
            return KeybindingCatalog.displayName(
                forBundleID: bundleID
            )
        }
        return KeybindingCatalog.localizedName(
            of: binding,
            config: config
        )
    }

    /// Formats shortcut combo string into native glyphs (#23).
    static func shortcutsCombo(_ combo: String) -> String {
        guard !combo.isEmpty else { return unset }
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }
}
