import KiwiDeskCore
import SwiftUI

/// The shelf's own colours in Colors & glass (#1517, #1857,
/// #2389); its accent rows sit in the role groups above.
struct KiwiShelfColorCard: View {
    @ObservedObject var model: SettingsModel

    private var gates: ColorsAndGlassGates {
        ColorsAndGlassGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.colorsDrawer.children
                .kiwishelfGroup,
            subsection: true,
            plated: false
        ) {
            ColorGrid {
                ColorsAndGlassRows(
                    model: model,
                    keys: ColorsRowOrder.kiwishelfColorRows
                )
            }
            // One greyed ROW in a live card takes its reason
            // beneath it as a live link, outside the dimmed
            // subtree — a header `?` scopes the card (#1310).
            if gates.needsOwnSentence(.kiwishelf(.borderColor)) {
                CrossReferenceRow(
                    prose: ColorsAndGlassHelp.shelfBorderReference,
                    linkTitle: SettingsDestination.bars.title,
                    destination: .bars
                )
            }
        }
    }
}

/// Renders colour rows, each greyed by its one verdict (#1857).
struct ColorsAndGlassRows: View {
    @ObservedObject var model: SettingsModel
    let keys: [SettingKey]

    private var gates: ColorsAndGlassGates {
        ColorsAndGlassGates(settings: model.config.settings)
    }

    var body: some View {
        ForEach(keys, id: \.id) { key in
            let verdict = gates.verdict(for: key)
            ColorsAndGlassRow(model: model, key: key)
                .modifier(
                    GreyOut(
                        active: verdict != nil,
                        help: verdict?.help ?? ""
                    )
                )
        }
    }
}
