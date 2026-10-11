import KiwiDeskCore
import SwiftUI

/// The shelf's own colours on Advanced Colours (#1517, #1857),
/// all at rest; its accent rows open the page in the role groups.
struct KiwiShelfColorCard: View {
    @ObservedObject var model: SettingsModel

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }

    var body: some View {
        // Section header help provides the block gate anchor (#527).
        SettingsSection(
            SettingsCatalog.advancedColors.kiwishelfGroup,
            help: gates.shelfDraws ? nil : AdvancedColorsHelp.kiwishelfOff
        ) {
            ColorGrid {
                AdvancedColorRows(
                    model: model,
                    keys: ColorsRowOrder.kiwishelfAtRest,
                    allows: gates.shelfDraws,
                    gateHelp: AdvancedColorsHelp.kiwishelfOff
                )
            }
            // One greyed ROW in a live card takes its reason
            // beneath it as a live link, outside the dimmed
            // subtree — a header `?` scopes the card (#1310).
            if gates.shelfBorderNeedsReference {
                CrossReferenceRow(
                    prose: AdvancedColorsHelp.shelfBorderReference,
                    linkTitle: SettingsDestination.bars.title,
                    destination: .bars
                )
            }
        }
    }
}

/// Renders color rows with parallel container and row-level gates.
struct AdvancedColorRows: View {
    @ObservedObject var model: SettingsModel
    let keys: [SettingKey]
    var allows = true
    var gateHelp = ""

    var body: some View {
        ForEach(keys, id: \.id) { key in
            let gate = Self.gate(allows: allows, key: key)
            AdvancedColorRow(
                model: model,
                key: key,
                ownPredicateLive: gate.rowPredicateLive
            )
            .modifier(
                GreyOut(active: gate.containerGrey, help: gateHelp)
            )
        }
    }

    /// Resolves container gate and row predicate state for a setting key.
    nonisolated static func gate(
        allows: Bool,
        key: SettingKey
    ) -> (rowPredicateLive: Bool, containerGrey: Bool) {
        let exempt = key.placement.exemptFromContainerGate
        return (
            rowPredicateLive: allows || exempt,
            containerGrey: !allows && !exempt
        )
    }
}
