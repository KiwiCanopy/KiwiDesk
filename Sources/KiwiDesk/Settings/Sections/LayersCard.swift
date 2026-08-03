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

    /// One declaration, two chromes — force-expanded once a
    /// layer exists, collapsible before that. The
    /// force-expansion binding is the drawer-with-its-own-rules
    /// seam `SettingsDisclosure` already carries for Gaps, which
    /// is also why this stays a single catalog declaration: a
    /// card that is sometimes at rest must not become two search
    /// anchors for one thing.
    var body: some View {
        SettingsDisclosure(
            SettingsCatalog.shortcuts.layersCard,
            chrome: .card,
            isExpanded: layersExist ? .constant(true) : $expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                LayerStripEditor(model: model, selected: $selected)
                if layersExist {
                    KeybindingFamilyRows(
                        model: model,
                        bindings: $bindings,
                        key: .shortcuts(.switchToLayer),
                        expander: expander
                    )
                }
            }
            .padding(.top, 8)
        }
    }
}
