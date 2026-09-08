import KiwiDeskCore
import SwiftUI

/// The Desktop families in a shortcut group: behind their own
/// offer, opened on arrival once one is bound (#1125).
///
/// A Desktop is macOS's arrangement rather than KiwiDesk's, the
/// seed authors none of these, and they scale per Desktop — so a
/// fresh install met a dozen rows for a concept the app has not
/// introduced. The offer is the door: withholding them outright
/// would leave no way in, their labels being dynamic and so
/// unreachable by search.
struct DesktopShortcutsOffer: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    /// The families to draw, the interleaved follower included.
    let keys: [SettingKey]
    let drawer: SettingsDrawer<SettingsNoChildren>
    let expander: ShortcutsFamilyRows
    @State private var expanded = false

    /// Whether the families are the user's own setup rather than
    /// an offer, asked of the resolver rather than re-derived
    /// (`ShortcutsGates`). It seeds the drawer OPEN and never
    /// swaps the container: branching the view here would tear
    /// the subtree down at the instant the user records their
    /// first Desktop combo — inside this drawer, with the
    /// recorder focused — and the reverse would shut the door on
    /// rows they were editing.
    var bound: Bool {
        ShortcutsGates(config: model.config).desktopBindingsExist
    }

    /// Whether there is anything to draw at all: with no bridge
    /// and nothing bound the families expand to nothing, and a
    /// door opening on an empty drawer is worse than no door.
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
            // Open on arrival once bound — never forced shut, so
            // a collapse the user chose survives the visit.
            .onAppear { if bound { expanded = true } }
        }
    }

    /// The one explanation of a Desktop against a Space —
    /// authored here, not per mount, so both doors carry the
    /// same sentence (#1114, #818).
    /// Internal rather than private so the guard can compare the
    /// two mounts' sentences directly, which is gui.md's
    /// instrument for a predicate a source scan keeps missing.
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

    @ViewBuilder private var families: some View {
        ForEach(keys, id: \.id) { key in
            KeybindingFamilyRows(
                model: model,
                bindings: $bindings,
                key: key,
                expander: expander,
                // The drawer's own title separates these from
                // their siblings, so a family heading under it
                // would only echo it (localization + design
                // review, 2026-09-04).
                showsHeading: false
            )
        }
    }
}
