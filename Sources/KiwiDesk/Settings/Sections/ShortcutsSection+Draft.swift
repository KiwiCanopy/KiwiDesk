import KiwiDeskCore
import SwiftUI

/// The section's reads of the draft.
extension ShortcutsSection {
    var advancedDrawerCaption: String {
        L(
            "shortcuts.advanced.caption",
            "This is the "
                + "power-user escape hatch — the "
                + "groups above cover the built-in "
                + "actions."
        )
    }

    /// The Lua bindings section's shut line: the selected layer's
    /// bindings by name once one exists, or what one is.
    var luaSummary: String {
        let names = bindingsBinding.wrappedValue
            .filter(ShortcutsGates.isLuaBinding)
            .map(AdvancedLuaGroup.rowName)
        guard !names.isEmpty else {
            return L("shortcuts.lua.summary", "Bind any Lua to a key")
        }
        return LocalizedList.join(names)
    }

    /// Family-to-rows expansion for the selected layer.
    var expander: ShortcutsFamilyRows {
        ShortcutsFamilyRows.ofDraft(model, layer: selected)
    }

    /// Falls back to the default layer if the remembered
    /// selection no longer exists (e.g. after a reload).
    func ensureSelection() {
        if !model.config.layers.contains(
            where: { $0.name == selected }
        ) {
            // Nil rather than the name: `nav`'s own coalescing
            // is the one place the landing is decided (#1127).
            model.nav.shortcutsLayer = nil
        }
    }
}
