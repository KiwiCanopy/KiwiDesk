import KiwiDeskCore
import SwiftUI

/// The two role groups that open Advanced Colours, side by side
/// (#1857): each holds one half of both colour-vision pairs, so
/// the halves that must stay apart are read together.
struct RoleColorCards: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            RoleColorCard(
                model: model,
                control: SettingsCatalog.advancedColors.accentGroup,
                caption: L(
                    "colors.accent.caption",
                    "The active Space, the focus border and the "
                        + "window you drag."
                ),
                keys: ColorsRowOrder.accentAtRest
            )
            RoleColorCard(
                model: model,
                control: SettingsCatalog.advancedColors
                    .secondAccentGroup,
                caption: L(
                    "colors.second_accent.caption",
                    "The focused window on the Space Bar, and where "
                        + "a dragged window lands."
                ),
                keys: ColorsRowOrder.secondAccentAtRest
            )
        }
    }
}

/// One role group: its rows, each greyed by its own surface, and
/// a live link beneath for each page whose switch dims one (#1310).
struct RoleColorCard: View {
    @ObservedObject var model: SettingsModel
    let control: SettingsControl
    let caption: String
    let keys: [SettingKey]

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(control, caption: caption) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(keys, id: \.id) { key in
                    AdvancedColorRows(
                        model: model,
                        keys: [key],
                        allows: allows(key),
                        gateHelp: AdvancedColorsHelp.kiwishelfOff
                    )
                }
            }
            if keys.contains(.spaceBar(.spaceBarFocusedItemColor)),
                gates.focusedItemNeedsReference
            {
                CrossReferenceRow(
                    prose: AdvancedColorsHelp.focusedItemReference,
                    linkTitle: SettingsDestination.bars.title,
                    destination: .bars
                )
            }
            ForEach(
                gates.dimmedDestinations(of: keys),
                id: \.self
            ) { destination in
                CrossReferenceRow(
                    prose: AdvancedColorsHelp.dimmedReference,
                    linkTitle: destination.title,
                    destination: destination
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The shelf's rows grey as a unit while no bar shows; every
    /// other row greys on its own surface's switch.
    private func allows(_ key: SettingKey) -> Bool {
        switch key {
        case .kiwishelf, .spaceBar: return gates.shelfDraws
        default: return true
        }
    }
}
