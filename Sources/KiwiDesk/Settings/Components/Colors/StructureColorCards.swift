import KiwiDeskCore
import SwiftUI

/// Borders and Drag color groups on Advanced Colours.
struct BorderColorCard: View {
    @ObservedObject var model: SettingsModel

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }

    var body: some View {
        // Section header help provides the row-gate anchor (#527).
        SettingsSection(
            SettingsCatalog.advancedColors.bordersGroup,
            caption: caption,
            help: gates.bordersHeaderHelp
        ) {
            ColorGrid {
                AdvancedColorRows(
                    model: model,
                    keys: ColorsRowOrder.bordersAtRest
                )
            }
        }
    }

    private var caption: String {
        L(
            "colors.borders.caption",
            "The ring around the focused window, and the mark on "
                + "a sticky one."
        )
    }
}

/// Drag visuals twinned columns (#231, #527).
struct DragColorCard: View {
    @ObservedObject var model: SettingsModel

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.advancedColors.dragGroup,
            caption: caption
        ) {
            HStack(alignment: .top, spacing: 16) {
                column(
                    title: L("drag.ghost", "Ghost"),
                    ghost: true,
                    keys: ColorsRowOrder.dragGhostColumn
                )
                column(
                    title: L("drag.drop_zone", "Drop zone"),
                    ghost: false,
                    keys: ColorsRowOrder.dragDropZoneColumn
                )
            }
        }
    }

    /// Column layout for ghost and drop zone visuals (#231).
    private func column(
        title: String,
        ghost: Bool,
        keys: [SettingKey]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let help = gates.dragHeaderHelp(ghost: ghost) {
                    HelpButton(explanation: help, subject: title)
                }
            }
            AdvancedColorRows(model: model, keys: keys)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var caption: String {
        L(
            "colors.drag.caption",
            "The window you picked up, and the slot it will "
                + "drop into."
        )
    }
}
