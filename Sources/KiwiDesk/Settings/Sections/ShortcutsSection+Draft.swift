import KiwiDeskCore
import SwiftUI

/// The section's reads of the draft.
extension ShortcutsSection {
    var advancedDrawerCaption: String {
        L(
            "shortcuts.advanced.caption",
            "Bind any Lua to a hotkey. This is the "
                + "power-user escape hatch — the "
                + "groups above cover the built-in "
                + "actions."
        )
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
