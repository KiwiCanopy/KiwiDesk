import KiwiDeskCore
import SwiftUI

/// The two role groups that open Advanced Colours, side by side,
/// stacked where the window's rows stack (#1857): the halves of
/// each colour-vision pair are read together.
struct RoleColorCards: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.settingsWidth) private var width

    var body: some View {
        let layout =
            width.stacksRows
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        layout {
            ForEach(ColorRole.allCases, id: \.self) { role in
                RoleColorCard(model: model, role: role)
            }
        }
    }
}

/// One role group: its rows, each greyed by its verdict, and a
/// live link beneath for each reason (#1310).
struct RoleColorCard: View {
    @ObservedObject var model: SettingsModel
    let role: ColorRole

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(role.control, caption: role.caption) {
            VStack(alignment: .leading, spacing: 8) {
                AdvancedColorRows(model: model, keys: role.keys)
            }
            if role.keys.contains(.spaceBar(.spaceBarFocusedItemColor)),
                gates.needsOwnSentence(.spaceBar(.spaceBarFocusedItemColor))
            {
                CrossReferenceRow(
                    prose: AdvancedColorsHelp.focusedItemReference,
                    linkTitle: SettingsDestination.bars.title,
                    destination: .bars
                )
            }
            ForEach(
                gates.dimmedDestinations(of: role.keys),
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
}
