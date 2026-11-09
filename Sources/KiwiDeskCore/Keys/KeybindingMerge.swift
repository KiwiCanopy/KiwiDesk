import Foundation

/// Folds recovered keybinding layers into GuiConfig on shortcut
/// import (#4): rows upsert by combo so re-import refreshes, not
/// duplicates. Sibling `KeyLayerOverride.resolved(onto:)` (#55)
/// merges the same key with OPPOSITE icon precedence — both are
/// correct for their direction; do not unify them.
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

    /// Folds one recovered layer into config, preserving existing layer icons.
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
            // The row is replaced whole, its identity kept: what it
            // says of itself follows its source (#2544), and a
            // sequence's steps with it (#1871).
            var replaced = row
            replaced.id = bindings[index].id
            bindings[index] = replaced
        } else {
            bindings.append(row)
        }
    }
}
