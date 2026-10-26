import KiwiDeskCore
import SwiftUI

/// The macOS Desktops section (#2655): every Desktop verb in one
/// place, after Move windows. The switch cue leads; Go to Desktop,
/// seeded on every install, sits at rest; the moves wait behind
/// the section's drawer, which opens on arrival once one is bound.
///
/// The section is removed, never greyed, where the families
/// expand to nothing — no window-management bridge, no reachable
/// Desktop — and search refuses its two names on the same bridge
/// question (`SettingsSearchIndex.bridgeGatedControls`).
struct MacOSDesktopsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows
    @State private var movesExpanded = false

    /// Whether the section draws at all: a card over no rows is
    /// worse than none. The jump bar asks the same question.
    static func hasRows(_ expander: ShortcutsFamilyRows) -> Bool {
        hasRows(
            ShortcutsRowOrder.macosDesktopsAtRest
                + ShortcutsRowOrder.macosDesktopsMore,
            expander
        )
    }

    /// Whether the drawer draws: a door opening on nothing is
    /// worse than no door.
    static func movesHaveRows(_ expander: ShortcutsFamilyRows) -> Bool {
        hasRows(ShortcutsRowOrder.macosDesktopsMore, expander)
    }

    private static func hasRows(
        _ keys: [SettingKey],
        _ expander: ShortcutsFamilyRows
    ) -> Bool {
        keys.contains { !expander.renderedRows(for: $0).isEmpty }
    }

    /// The drawer's hold-open, asked of the resolver. It seeds the
    /// drawer OPEN and never swaps the container: branching here
    /// would tear the subtree down at the instant the user records
    /// their first move, with the recorder focused (#1125).
    var movesBound: Bool {
        ShortcutsGates(config: model.config).desktopMovesBound
    }

    @ViewBuilder var body: some View {
        if Self.hasRows(expander) {
            SettingsSection(
                SettingsCatalog.shortcuts.desktopsSection,
                help: helpText
            ) {
                // `ShortcutsRowOrder.macosDesktopsList`, drawn by
                // its own view.
                DesktopCueRow(model: model)
                ForEach(ShortcutsRowOrder.macosDesktopsAtRest, id: \.id) {
                    family($0)
                }
                if Self.movesHaveRows(expander) {
                    moves
                }
            }
        }
    }

    private var moves: some View {
        SettingsDisclosure(
            SettingsCatalog.shortcuts.desktopMoves,
            isExpanded: $movesExpanded,
            scrollHoisted: true
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ShortcutsRowOrder.macosDesktopsMore, id: \.id) {
                    family($0)
                }
            }
            .padding(.top, 8)
        }
        // Open on arrival once bound — never forced shut, so a
        // collapse the user chose survives the visit.
        .onAppear { if movesBound { movesExpanded = true } }
    }

    /// The one explanation of a Desktop against a Space (#1114,
    /// #818), on the section header.
    var helpText: String {
        L(
            "shortcuts.desktops.help",
            "Desktops are macOS's own Spaces, not KiwiDesk's. "
                + "KiwiDesk arranges windows inside its own "
                + "Spaces, so most setups never need these: "
                + "switching a Desktop moves your whole "
                + "environment, not a window, and each Desktop "
                + "keeps its own Spaces. If you do work across "
                + "Desktops, bind a profile per Desktop in "
                + "**%1$@**.",
            L("desktops.title", "Profiles per macOS Desktop")
        )
    }

    private func family(_ key: SettingKey) -> some View {
        KeybindingFamilyRows(
            model: model,
            bindings: $bindings,
            key: key,
            expander: expander,
            // The section's and the drawer's titles name these
            // rows, so a family heading would only echo them.
            showsHeading: false
        )
    }
}
