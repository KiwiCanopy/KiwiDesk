import Foundation

/// Folds recovered keybinding layers into an edited `GuiConfig`
/// for the GUI's "Import current shortcuts" (#4): layers are
/// matched by name (appended when new) and rows upserted by their
/// combo, so re-importing refreshes an existing shortcut instead
/// of duplicating it. Pure and Core-typed, so the dedup logic the
/// import depends on is unit-tested without the SwiftUI layer.
///
/// Sibling keyed merge: `KeyLayerOverride.resolved(onto:)` (#55
/// profile override) merges by the same name×combo key but with
/// the OPPOSITE icon precedence (override-wins). Both are
/// correct for their direction — do not unify them.
public enum KeybindingMerge {
    /// Merges every recovered layer into `config` in place.
    public static func merge(
        recovered: [KeyLayer],
        into config: inout GuiConfig
    ) {
        for layer in recovered {
            merge(layer, into: &config)
        }
    }

    /// Folds one recovered layer into `config` — updating the
    /// same-named layer's rows, or appending the layer when new. An
    /// existing layer keeps its icon unless it had none.
    private static func merge(
        _ recovered: KeyLayer,
        into config: inout GuiConfig
    ) {
        guard
            let index = config.layers.firstIndex(
                where: { $0.name == recovered.name }
            )
        else {
            config.layers.append(recovered)
            return
        }
        if config.layers[index].icon == nil {
            config.layers[index].icon = recovered.icon
        }
        for row in recovered.bindings {
            upsert(row, into: &config.layers[index].bindings)
        }
    }

    /// Replaces the row bound to the same combo, or appends when
    /// that combo is free. A combo-less recovered row is ignored —
    /// it can't be keyed and would never fire.
    static func upsert(
        _ row: KeyBinding,
        into bindings: inout [KeyBinding]
    ) {
        guard !row.combo.isEmpty else { return }
        if let index = bindings.firstIndex(
            where: { $0.combo == row.combo }
        ) {
            bindings[index].lua = row.lua
            bindings[index].kind = row.kind
            bindings[index].label = row.label
        } else {
            bindings.append(row)
        }
    }
}
