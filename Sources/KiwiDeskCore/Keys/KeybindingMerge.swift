import Foundation

/// Folds recovered keybinding modes into an edited `GuiConfig`
/// for the GUI's "Import current shortcuts" (#4): modes are
/// matched by name (appended when new) and rows upserted by their
/// combo, so re-importing refreshes an existing shortcut instead
/// of duplicating it. Pure and Core-typed, so the dedup logic the
/// import depends on is unit-tested without the SwiftUI layer.
public enum KeybindingMerge {
    /// Merges every recovered mode into `config` in place.
    public static func merge(
        recovered: [KeyMode],
        into config: inout GuiConfig
    ) {
        for mode in recovered {
            merge(mode, into: &config)
        }
    }

    /// Folds one recovered mode into `config` — updating the
    /// same-named mode's rows, or appending the mode when new. An
    /// existing mode keeps its icon unless it had none.
    private static func merge(
        _ recovered: KeyMode,
        into config: inout GuiConfig
    ) {
        guard
            let index = config.modes.firstIndex(
                where: { $0.name == recovered.name }
            )
        else {
            config.modes.append(recovered)
            return
        }
        if config.modes[index].icon == nil {
            config.modes[index].icon = recovered.icon
        }
        for row in recovered.bindings {
            upsert(row, into: &config.modes[index].bindings)
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
