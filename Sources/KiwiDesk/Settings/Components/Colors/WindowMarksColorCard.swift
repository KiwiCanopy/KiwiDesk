import KiwiDeskCore
import SwiftUI

/// The marks on windows that are not the focus (#1857): the
/// unfocused border and the sticky and floating marks.
struct WindowMarksColorCard: View {
    @ObservedObject var model: SettingsModel

    private var gates: ColorsAndGlassGates {
        ColorsAndGlassGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.colorsDrawer.children
                .windowMarksGroup,
            caption: L(
                "colors.window_marks.caption",
                "The border on unfocused windows, and the marks on "
                    + "sticky and floating ones."
            ),
            subsection: true,
            plated: false
        ) {
            ColorGrid {
                ColorsAndGlassRows(
                    model: model,
                    keys: ColorsRowOrder.windowMarksRows
                )
            }
            // One greyed ROW in a live card takes its reason
            // beneath it as a live link (#1310).
            if gates.needsOwnSentence(.borders(.borderUnfocusedColor)) {
                CrossReferenceRow(
                    prose: ColorsAndGlassHelp.unfocusedReference,
                    linkTitle: SettingsDestination.gapsAndBorders.title,
                    destination: .gapsAndBorders
                )
            }
            ForEach(
                gates.dimmedDestinations(
                    of: ColorsRowOrder.windowMarksRows
                ),
                id: \.self
            ) { destination in
                CrossReferenceRow(
                    prose: ColorsAndGlassHelp.dimmedReference,
                    linkTitle: destination.title,
                    destination: destination
                )
            }
        }
    }
}
