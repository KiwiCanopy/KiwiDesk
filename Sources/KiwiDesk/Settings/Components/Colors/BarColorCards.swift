import KiwiDeskCore
import SwiftUI

/// The shelf's one colour group on Advanced Colours (#1517):
/// every colour both bars draw, plus the Space Bar's own
/// focused-window ink.
struct KiwiShelfColorCard: View {
    @ObservedObject var model: SettingsModel
    @State private var moreExpanded = false

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }
    private var allows: Bool {
        gates.bars.containerReason(for: .kiwishelf) == nil
    }

    var body: some View {
        // Section header help provides the block gate anchor (#527).
        SettingsSection(
            SettingsCatalog.advancedColors.kiwishelfGroup,
            help: allows ? nil : AdvancedColorsHelp.kiwishelfOff
        ) {
            ColorGrid {
                AdvancedColorRows(
                    model: model,
                    keys: ColorsRowOrder.kiwishelfAtRest,
                    allows: allows,
                    gateHelp: AdvancedColorsHelp.kiwishelfOff
                )
            }
            SettingsDisclosure(
                SettingsCatalog.advancedColors.kiwishelfMore,
                isExpanded: $moreExpanded,
                scrollHoisted: true,
                summary: summary
            ) {
                ColorGrid {
                    AdvancedColorRows(
                        model: model,
                        keys: ColorsRowOrder.kiwishelfMore,
                        allows: allows,
                        gateHelp: AdvancedColorsHelp.kiwishelfOff
                    )
                }
                .padding(.top, 8)
                // One greyed ROW in a live card takes its reason
                // beneath it as a live link, outside the dimmed
                // subtree — a header `?` scopes the card (#1310).
                if gates.focusedItemNeedsReference {
                    CrossReferenceRow(
                        prose: AdvancedColorsHelp.focusedItemReference,
                        linkTitle: SettingsDestination.bars.title,
                        destination: .bars
                    )
                }
            }
        }
    }

    private var summary: String {
        L(
            "colors.more.kiwishelf.summary",
            "Hover, badges, focused window"
        )
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
