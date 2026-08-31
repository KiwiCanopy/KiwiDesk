import AppKit
import KiwiDeskCore

/// Layer switching command generation and rename refactoring (#4).
extension KeybindingCatalog {

    /// Authors layer switch command matching import classifier syntax (#4).
    static func switchLayerCommand(_ name: String) -> NavCommand {
        NavCommand(
            label: "Switch to \(name)",
            lua: "KiwiDesk.switch_layer(\(quote(name)))",
            displayLabel: {
                L(
                    "keybinding.switch_to_layer",
                    "Switch to %1$@",
                    name
                )
            }
        )
    }

    /// Renames a layer across all configuration bindings (#4).
    static func renameLayer(
        in layers: [KeyLayer],
        from old: String,
        to new: String
    ) -> [KeyLayer] {
        // `default` is the config's anchor layer ("always the
        // active one after the app starts") — no entry point
        // may rename it, today's UI gate or a future CLI's.
        guard old != KeyLayer.defaultName else { return layers }
        let oldCmd = switchLayerCommand(old)
        let newCmd = switchLayerCommand(new)
        return layers.map { layer in
            var layer = layer
            if layer.name == old { layer.name = new }
            layer.bindings = layer.bindings.map { binding in
                var binding = binding
                if binding.lua == oldCmd.lua {
                    binding.lua = newCmd.lua
                    binding.label = newCmd.label
                }
                return binding
            }
            return layer
        }
    }
}
