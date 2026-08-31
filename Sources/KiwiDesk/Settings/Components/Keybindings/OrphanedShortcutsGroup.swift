import KiwiDeskCore
import SwiftUI

/// Display and editing group for orphaned space shortcuts (#92).
/// Surfaced, never pruned: the binding revives when its space
/// returns, so dropping it on save would lose config across a
/// routine profile/monitor swap.
struct OrphanedShortcutsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let spaces: [SpaceID]

    var body: some View {
        let commands = OrphanedShortcuts.commands(
            bindings: bindings,
            spaces: spaces,
            icons: model.config.settings.spaceIcons
        )
        if !commands.isEmpty {
            SettingsSection(
                SettingsCatalog.shortcuts.inactiveShortcuts
            ) {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
