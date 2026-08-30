import KiwiDeskCore
import SwiftUI

/// Space Bar color group on Advanced Colours.
struct SpaceBarColorCard: View {
    @ObservedObject var model: SettingsModel
    @State private var moreExpanded = false

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }
    private var allows: Bool {
        gates.bars.containerReason(for: .spaceBar) == nil
    }

    var body: some View {
        // Section header help provides the block gate anchor (#527).
        SettingsSection(
            SettingsCatalog.advancedColors.spaceBarGroup,
            help: allows ? nil : AdvancedColorsHelp.spaceBarOff
        ) {
            ColorGrid {
                AdvancedColorRows(
                    model: model,
                    keys: ColorsRowOrder.spaceBarAtRest,
                    allows: allows,
                    gateHelp: AdvancedColorsHelp.spaceBarOff
                )
            }
            SettingsDisclosure(
                SettingsCatalog.advancedColors.spaceBarMore,
                isExpanded: $moreExpanded,
                scrollHoisted: true,
                summary: summary
            ) {
                ColorGrid {
                    AdvancedColorRows(
                        model: model,
                        keys: ColorsRowOrder.spaceBarMore,
                        allows: allows,
                        gateHelp: AdvancedColorsHelp.spaceBarOff
                    )
                }
                .padding(.top, 8)
            }
        }
    }

    private var summary: String {
        L(
            "colors.more.space_bar.summary",
            "Plate, highlight, hover, badges"
        )
    }
}

struct AppBarColorCard: View {
    @ObservedObject var model: SettingsModel
    @State private var moreExpanded = false

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }
    private var allows: Bool {
        gates.bars.containerReason(for: .appBar) == nil
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.advancedColors.appBarGroup,
            help: allows ? nil : AdvancedColorsHelp.appBarOff
        ) {
            ColorGrid {
                AdvancedColorRows(
                    model: model,
                    keys: ColorsRowOrder.appBarAtRest,
                    allows: allows,
                    gateHelp: AdvancedColorsHelp.appBarOff
                )
            }
            SettingsDisclosure(
                SettingsCatalog.advancedColors.appBarMore,
                isExpanded: $moreExpanded,
                scrollHoisted: true,
                summary: summary
            ) {
                ColorGrid {
                    AdvancedColorRows(
                        model: model,
                        keys: ColorsRowOrder.appBarMore,
                        allows: allows,
                        gateHelp: AdvancedColorsHelp.appBarOff
                    )
                }
                .padding(.top, 8)
            }
        }
    }

    private var summary: String {
        L(
            "colors.more.app_bar.summary",
            "Item, active item, hover, badges"
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
    static func gate(
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
