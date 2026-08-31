import KiwiDeskCore
import SwiftUI

/// Keybinding layer management card — a bespoke container
/// (`ShortcutsRowOrder.bespokeContainers`). Config presence
/// expands the simple surface: a configured layer is the user's
/// own setup, so the card is AT REST the moment one exists, in
/// both modes. Getting this backwards hides a user's own
/// configuration — an earlier draft shipped exactly that by
/// reading the tier as `.showMore`.
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

    /// Whether the card is offered: an always-open card, or no
    /// card at all (owner ruling 2026-08-04) — absent until earned
    /// by having a layer or Power User (`SpaceOverrideOffer`,
    /// #678 8c). Static so the STRIP inside asks the same
    /// predicate rather than keeping a second copy (#816).
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
