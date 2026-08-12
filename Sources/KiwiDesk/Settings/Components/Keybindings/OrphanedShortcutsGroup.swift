import KiwiDeskCore
import SwiftUI

/// Inactive / orphaned shortcuts (#92): a space-targeting
/// `.navigation` binding whose space is no longer in the
/// current space list — e.g. `option+6 → Go to Space 6` after
/// switching from an 8-space to a 4-space profile. The per-
/// space catalog sections render one row per *live* space, so
/// without this section such a binding was invisible while
/// still Carbon-registered (pressing it silently recreates the
/// space) and still holding its combo (hard-blocking the
/// recorder with a holder the user could not see or reach).
///
/// Surfaced, never pruned: the binding is only orphaned
/// relative to the current space set and comes back to life
/// when its space returns, so dropping it on save would lose
/// config across a routine profile/monitor swap. Rows here are
/// ordinary `NavRow`s — rebind, clear, and the recorder's
/// "Go to" (which scrolls to the row's Lua id) all work.
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
