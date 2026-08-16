import KiwiDeskCore
import SwiftUI

/// The Borders and Drag groups on Advanced Colours (turn 12b).
///
/// Neither has a "More colors" drawer, and the asymmetry with the
/// two bar groups is deliberate rather than an oversight: a
/// drawer that hides one or two swatches of a two-column grid
/// costs a title, a click and a remembered state to save half a
/// grid line — it moves a decision instead of removing one. The
/// drawer is earned by row count. Three and four rows do not earn
/// it; ten and eight do.
struct BorderColorCard: View {
    @ObservedObject var model: SettingsModel

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }

    var body: some View {
        // No container gate here — the `.borders` census container
        // carries none, because the sticky tint shares it and
        // always paints the on-window mark. The header `?`
        // therefore answers for the ROW gates, which is the one
        // thing this area cannot leave to hover text: their
        // switches are on another page (#527).
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

/// Drag visuals, as the #231 twin columns: each column leads with
/// its own preview and holds its own two tints, so tuning one
/// never scrolls the other's preview off screen. The colour page
/// reproduces the pairing because the two visuals are still
/// edited by comparison — that is the whole reason they are twins.
///
/// The columns are plain subheadings, not `SettingsSection`s: the
/// Gaps & Borders drag editor already anchors "Ghost" and "Drop
/// zone" for search, and a second pair carrying the same words
/// would return two hits for one question. The card is the
/// anchor; the subheadings carry their own `HelpButton`, which is
/// what keeps the #527 promise — a live `?` OUTSIDE the dimmed
/// rows, per column, so the sentence can name that column's own
/// switch and the page it lives on.
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

    /// One column: subheading, preview, its two tints.
    ///
    /// The narrowed label axis (#231) is passed by `dragRow`
    /// itself, NOT published here as an environment value:
    /// `HexColorField.labelWidth` is a plain parameter that
    /// reads no environment, so a publish would reach nothing —
    /// which is precisely how these columns came to render on
    /// the full-width axis in the first place.
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
