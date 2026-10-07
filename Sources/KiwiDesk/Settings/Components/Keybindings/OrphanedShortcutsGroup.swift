import KiwiDeskCore
import SwiftUI

/// Display and editing group for orphaned space shortcuts (#92)
/// and switches to a layer the config no longer lists (#2016).
/// Surfaced, never pruned: the binding revives when its space
/// returns, so dropping it on save would lose config across a
/// routine profile/monitor swap.
struct OrphanedShortcutsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let spaces: [SpaceID]
    let layers: [String]

    var body: some View {
        let commands = OrphanedShortcuts.commands(
            bindings: bindings,
            spaces: spaces,
            layers: layers,
            icons: model.config.settings.spaceIcons
        )
        let switches = commands.filter {
            KeybindingCatalog.switchTarget(of: $0.lua) != nil
        }
        if !commands.isEmpty {
            SettingsSection(
                SettingsCatalog.shortcuts.inactiveShortcuts
            ) {
                if switches.count < commands.count {
                    captionText(caption)
                }
                if !switches.isEmpty {
                    captionText(layerCaption)
                }
                // Dimmed as a block: the rows stay fully
                // interactive, but read as parked rather
                // than part of the live space list.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(commands) { command in
                        NavRow(
                            model: model,
                            bindings: $bindings,
                            command: command
                        )
                    }
                }
                .opacity(0.6)
            }
        }
    }

    private func captionText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var layerCaption: String {
        L(
            "shortcuts.inactive.layer_caption",
            "These shortcuts switch to a layer that is not in "
                + "this profile's layer list. Rebind or remove "
                + "them here."
        )
    }

    private var caption: String {
        L(
            "shortcuts.inactive.caption",
            "These shortcuts target Spaces that are not "
                + "in the current Space list. They still "
                + "work — pressing one recreates its "
                + "Space — and they keep their key combo. "
                + "Rebind or remove them here; they become "
                + "active again when their Space returns."
        )
    }
}
