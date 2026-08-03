import AppKit
import KiwiDeskCore

/// The layer-switching half of the catalog: the row that
/// switches to a named layer, and the pure rename that
/// rewrites those rows across a config.
///
/// Split from `KeybindingCatalog.swift` on §2's file-size
/// limit, on the seam the file already marked. Both halves
/// stay the single authority for the Lua they author, which
/// is what keeps the writer and the import classifier
/// matching byte-for-byte (#4).
extension KeybindingCatalog {

    /// The Change-Layers row that switches to `name`. The one
    /// authority for this Lua so the writer (`SwitchLayersGroup`)
    /// and the import classifier match byte-for-byte — a drift
    /// here would silently demote imports to Custom (#4).
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

    /// Renames a layer across `layers`: the layer itself plus
    /// every switch-layer row targeting it, rewritten through
    /// `switchLayerCommand` so writer and import classifier
    /// keep matching byte-for-byte (#4). Pure — the tested
    /// core of the Shortcuts header's rename.
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
