import KiwiDeskCore
import SwiftUI

/// The Track families in the Move windows group: behind their
/// own offer, opened on arrival once the layout is in play
/// (#1440) — the Desktop offer's shape (#1125), one mount.
///
/// The rows mean nothing outside the Track layout, and the seed
/// binds none of them; the door keeps them reachable (grey
/// don't hide) while a user without tracks meets one title
/// rather than four rows.
struct TrackShortcutsOffer: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let keys: [SettingKey]
    let drawer: SettingsDrawer<SettingsNoChildren>
    let expander: ShortcutsFamilyRows
    @State private var expanded = false

    /// Whether the layout is in play, asked of the resolver
    /// rather than re-derived (`ShortcutsGates`). It seeds the
    /// drawer OPEN and never swaps the container, for the
    /// Desktop offer's reason: a recorder focused inside it must
    /// survive the first recorded combo.
    var bound: Bool {
        ShortcutsGates(config: model.config).trackInUse
    }

    /// Whether there is anything to draw at all.
    var hasRows: Bool {
        keys.contains { !expander.renderedRows(for: $0).isEmpty }
    }

    @ViewBuilder var body: some View {
        if hasRows {
            SettingsDisclosure(
                drawer,
                isExpanded: $expanded,
                scrollHoisted: true
            ) {
                families
            } accessory: {
                HelpButton(
                    explanation: helpText,
                    subject: drawer.control.text
                )
            }
            // Open on arrival once in play — never forced shut.
            .onAppear { if bound { expanded = true } }
        }
    }

    /// What previous and next mean in a track — the one fact the
    /// rows cannot carry (`docs/design-decisions.md` ▸ Two
    /// vocabularies, one split). Interpolates the Layout
    /// Defaults label rather than quoting it (#818).
    var helpText: String {
        L(
            "shortcuts.tracks.help",
            "In the track layout, windows line up in tracks — "
                + "columns, or rows if the axis is flipped — and "
                + "several can share one. Previous is the track "
                + "to the left or above, next the one to the "
                + "right or below. Tune the layout in **%1$@**.",
            SettingsDestination.layoutDefaults.title
        )
    }

    @ViewBuilder private var families: some View {
        ForEach(keys, id: \.id) { key in
            KeybindingFamilyRows(
                model: model,
                bindings: $bindings,
                key: key,
                expander: expander,
                // The drawer's own title separates these from
                // their siblings; a family heading would echo it.
                showsHeading: false
            )
        }
    }
}
