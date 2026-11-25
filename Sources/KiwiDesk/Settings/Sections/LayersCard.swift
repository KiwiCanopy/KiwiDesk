import KiwiDeskCore
import SwiftUI

/// Keybinding layer management on Shortcuts ▸ Personal — a bespoke
/// container (`ShortcutsRowOrder.bespokeContainers`), drawn open as
/// that part draws its offers (`docs/design-decisions.md` ▸ One
/// page, three parts). The layer pick itself is the page-wide strip
/// above the switcher (#3535): while only `default` exists, this
/// card holds the strip as the offer to add a layer; once one
/// exists, the strip moves above the switcher and this card holds
/// the "Switch to layer" keys. Never swapped for another container
/// while shown, so a recorder inside survives its first combo
/// (#1125).
struct LayersCard: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Binding var selected: String
    let expander: ShortcutsFamilyRows

    /// Whether configured layers exist (`ShortcutsGates`) — the
    /// census gate of the rows and which half the card draws.
    private var layersExist: Bool {
        ShortcutsGates(config: model.config).layersExist
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.shortcuts.layersCard.control,
            help: Self.help
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if layersExist {
                    KeybindingFamilyRows(
                        model: model,
                        bindings: $bindings,
                        key: .shortcuts(.switchToLayer),
                        expander: expander
                    )
                } else {
                    LayerStripEditor(model: model, selected: $selected)
                }
            }
        }
    }

    /// What a layer is, in the title's `?` (#3263).
    static var help: String {
        L(
            "shortcuts.layers.help",
            "Layers are alternate sets of shortcuts and "
                + "gestures — only the active layer's fire. Bind "
                + "a key below to switch between them. "
                + "\u{201C}default\u{201D} is the standard "
                + "layer and is always the active one after "
                + "the app starts."
        )
    }
}
