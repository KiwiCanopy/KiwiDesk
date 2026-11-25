import KiwiDeskCore
import SwiftUI

/// Keybinding layer management — a bespoke container
/// (`ShortcutsRowOrder.bespokeContainers`). On Built-in a
/// collapsible card (#2654) that opens on arrival once a layer
/// exists; on Personal an open card, as that part draws its offers
/// open (`docs/design-decisions.md` ▸ One page, three parts).
/// Neither is swapped for another container while shown, so a
/// recorder inside survives its first combo (#1125).
struct LayersCard: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Binding var selected: String
    let expander: ShortcutsFamilyRows
    @State private var expanded = false
    @Environment(\.shortcutsSegment) private var segment

    /// Whether configured layers exist (`ShortcutsGates`) — the
    /// census gate of the rows and the card's hold-open alike.
    private var layersExist: Bool {
        ShortcutsGates(config: model.config).layersExist
    }

    @ViewBuilder var body: some View {
        if segment == .personal {
            SettingsSection(
                SettingsCatalog.shortcuts.layersCard.control,
                help: Self.help
            ) {
                content
            }
        } else {
            SettingsCollapsibleSection(
                SettingsCatalog.shortcuts.layersCard,
                isExpanded: $expanded,
                summary: summary,
                help: Self.help
            ) {
                content
            }
            // Open on arrival once in use — never forced shut.
            .onAppear { if layersExist { expanded = true } }
        }
    }

    private var content: some View {
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

    /// What a layer is, in the title's `?` (#3263).
    static var help: String {
        L(
            "shortcuts.layers.help",
            "Layers are alternate shortcut sets — only the "
                + "active layer's shortcuts fire. Bind a "
                + "key below to switch between them. "
                + "\u{201C}default\u{201D} is the standard "
                + "layer and is always the active one after "
                + "the app starts."
        )
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
