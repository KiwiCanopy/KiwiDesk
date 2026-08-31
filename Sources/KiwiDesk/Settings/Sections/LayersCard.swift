import KiwiDeskCore
import SwiftUI

/// Keybinding layer management card container
/// (`KeybindingGroups.swift`, `ShortcutsRowOrder.bespokeContainers`).
struct LayersCard: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Binding var selected: String
    let expander: ShortcutsFamilyRows
    @State private var expanded = false

    /// Whether configured layers exist (`ShortcutsGates`).
    private var layersExist: Bool {
        ShortcutsGates(config: model.config)
            .inertReason(for: .shortcuts(.switchToLayer)) == nil
    }

    /// Whether layers card is offered in given settings mode
    /// (owner ruling 2026-08-04, `SpaceOverrideOffer`, #678 8c, #816).
    static func isOffered(
        config: GuiConfig,
        mode: SettingsMode
    ) -> Bool {
        ShortcutsGates(config: config)
            .inertReason(for: .shortcuts(.switchToLayer)) == nil
            || mode == .powerUser
    }

    private func offered(in mode: SettingsMode) -> Bool {
        Self.isOffered(config: model.config, mode: mode)
    }

    private var offered: Bool {
        offered(in: model.settingsMode)
    }

    /// Mode gating status for visual framing (#760, 2026-08-09).
    private var modeGated: Bool {
        !offered(in: .simple)
    }

    @ViewBuilder var body: some View {
        if offered {
            SettingsSection(
                SettingsCatalog.shortcuts.layersCard,
                modeGated: modeGated
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
        }
    }
}
