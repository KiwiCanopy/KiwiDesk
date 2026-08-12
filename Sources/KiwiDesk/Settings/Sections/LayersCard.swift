import KiwiDeskCore
import SwiftUI

// Split from `KeybindingGroups.swift` on the boundary the
// data already draws: that file holds the census-driven
// cards, whose rows come from a `ForEach` over an order
// list, and this is a BESPOKE container
// (`ShortcutsRowOrder.bespokeContainers`). It sits beside
// `LayerStripEditor`, which it mounts.

/// **Config presence expands the simple surface.** The census
/// tiers these `.immediate` behind a `layersExist` gate, which is
/// the tier's whole point: a configured layer is the user's own
/// setup, so the card is AT REST the moment one exists — in both
/// Settings modes, never re-earned. Only the offer to create the
/// first layer is withheld, and it stays behind a disclosure so
/// it is reachable rather than gone.
///
/// Getting this backwards hides a user's own configuration from
/// them, which is the failure the rule exists to prevent; an
/// earlier draft of this card did exactly that by reading the
/// tier as `.showMore`.
///
/// The header carries a label naming the layer being edited
/// whenever more than one exists, so which layer the rows below
/// belong to is answered even while this card is scrolled past.
struct LayersCard: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Binding var selected: String
    let expander: ShortcutsFamilyRows
    @State private var expanded = false

    /// The gate behind the `.immediate` tier — resolved through
    /// the census's own gate rather than re-derived here, so the
    /// declaration and the screen cannot disagree. Hiding a
    /// user's configured layers is what disagreement looks like,
    /// and this area shipped it once.
    private var layersExist: Bool {
        ShortcutsGates(config: model.config)
            .inertReason(for: .shortcuts(.switchToLayer)) == nil
    }

    /// **An always-open card, or no card at all** (owner ruling
    /// 2026-08-04). It shipped as a disclosure that force-expanded
    /// once a layer existed and offered itself collapsed before
    /// that — so in Simple, a user with no layers met a closed
    /// drawer for a concept they had no use for, on the one screen
    /// where every other card is at rest.
    ///
    /// The offer is now withheld the way every other advanced
    /// surface in this window is: absent until earned, and earned
    /// by *having a layer* or by turning Power User on — the same
    /// capability unlock as `SpaceOverrideOffer` (#678 8c), over
    /// its own data.
    ///
    /// **Nothing a user configured is ever hidden**: `layersExist`
    /// is the first term of the offer, so a Simple user with two
    /// layers keeps the card. Getting that backwards hides
    /// someone's own setup from them, which is the failure this
    /// card's earlier draft actually shipped by reading the tier
    /// as `.showMore`.
    /// Static, so the STRIP inside this card can ask the same
    /// predicate rather than keep a second copy of it: deleting
    /// the last custom layer retires this whole card in Simple
    /// mode, and the strip has to know that to decide whether
    /// naming a focus destination inside it means anything
    /// (#816). One predicate, the `HomeCardOrder.isOffered`
    /// shape one level down.
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

    /// One predicate, evaluated twice (#760): the card is
    /// mode-gated exactly when Simple would withhold it — so
    /// with layers configured it is Simple content and unmarked,
    /// and creating the first layer drops the weight as a plain
    /// bookkeeping fact, no wash (ui-designer, 2026-08-09).
    private var modeGated: Bool {
        !offered(in: .simple)
    }

    /// The selected layer decides what every card BELOW this one
    /// is showing, which is why it leads the area rather than
    /// tailing it — a control that reframes the whole page cannot
    /// sit under the page it reframes.
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
