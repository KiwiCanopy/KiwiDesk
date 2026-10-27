import KiwiDeskCore
import SwiftUI

/// Keybinding layer management — a bespoke container
/// (`ShortcutsRowOrder.bespokeContainers`) drawn as a collapsible
/// card (#2654). Config presence expands it: once a layer exists
/// the card opens on arrival, and it is never swapped for another
/// container, so a recorder inside survives its first combo
/// (#1125).
struct LayersCard: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Binding var selected: String
    let expander: ShortcutsFamilyRows
    @State private var expanded = false

    /// Whether configured layers exist (`ShortcutsGates`) — the
    /// census gate of the rows and the card's hold-open alike.
    private var layersExist: Bool {
        ShortcutsGates(config: model.config).layersExist
    }

    var body: some View {
        SettingsCollapsibleSection(
            SettingsCatalog.shortcuts.layersCard,
            isExpanded: $expanded,
            summary: summary
        ) {
            VStack(alignment: .leading, spacing: 12) {
                LayerStripEditor(
                    model: model,
                    selected: $selected
                )
                if layersExist {
                    KeybindingFamilyRows(
                        model: model,
                        bindings: $bindings,
                        key: .shortcuts(.switchToLayer),
                        expander: expander
                    )
                }
            }
        }
        // Open on arrival once in use — never forced shut.
        .onAppear { if layersExist { expanded = true } }
    }

    /// The layers by name once there is more than one, or what a
    /// layer is.
    private var summary: String {
        guard layersExist else {
            return L(
                "shortcuts.layers.summary",
                "Alternate shortcut sets, switched with a key"
            )
        }
        return LocalizedList.join(model.config.layers.map(\.name))
    }
}
