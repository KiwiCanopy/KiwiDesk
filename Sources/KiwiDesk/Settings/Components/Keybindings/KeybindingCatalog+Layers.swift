import AppKit
import KiwiDeskCore

/// Layer switching command generation, rename and delete (#4,
/// #2016).
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

    /// Renames a layer across all configuration bindings, rewritten
    /// through `switchLayerCommand` so writer and import classifier
    /// stay matched byte-for-byte (#4).
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

    /// Deletes a layer and every row switching to it — a row that
    /// switches to a deleted layer does nothing and has no row to
    /// remove it by (#2016). Only that one name: a switch row to a
    /// layer `init.lua` defines reads as dangling to this config.
    static func deleteLayer(
        in layers: [KeyLayer],
        named name: String
    ) -> [KeyLayer] {
        guard name != KeyLayer.defaultName else { return layers }
        let switchTo = switchLayerCommand(name).lua
        return layers.filter { $0.name != name }.map { layer in
            var layer = layer
            layer.bindings.removeAll { $0.lua == switchTo }
            return layer
        }
    }
}
