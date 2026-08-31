import KiwiDeskCore
import SwiftUI

/// Shared border width and corner style settings card
/// (`GapsBordersGates`, #754).
struct BordersCard: View {
    @ObservedObject var model: SettingsModel

    private var gates: GapsBordersGates {
        GapsBordersGates(settings: model.config.settings)
    }

    private var caption: String {
        L(
            "border.shared.caption",
            "The focus ring, the drag ghost and the drop zone "
                + "are strokes KiwiDesk draws around a window."
        )
    }

    /// A master writes over whatever the strokes hold, and Lua
    /// can leave them holding three different things. The gap
    /// masters answer that by greying; these cannot — no
    /// per-stroke row to send anyone to (`GapsBordersGates`
    /// carries the argument) — so a `?` appears exactly while the
    /// disagreement does.
    private var widthHelp: String? {
        gates.strokesDiffer(for: .borders(.borderWidthMaster))
            ? GapsBordersGateHelp.strokesDiffer : nil
    }

    private var cornersHelp: String? {
        gates.strokesDiffer(for: .borders(.borderCornerMaster))
            ? GapsBordersGateHelp.strokesDiffer : nil
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.gapsAndBorders.bordersCard,
            caption: caption
        ) {
            masters
        }
    }

    @ViewBuilder private var masters: some View {
        // One domain for all three strokes, starting at 1: a 0
        // here would be a third way to say "off" that turns off
        // all three — each stroke already has its own toggle.
        PtSlider(
            label: L("border.width", "Width"),
            value: model.borderWidthMaster,
            range: 1...20,
            help: widthHelp
        )
        // Optional-valued on purpose: a ring style and a drag
        // radius that disagree match no segment and the pill hides
        // itself (`SegmentedPickerUnmatchedTests`); whichever
        // segment is then tapped ends the disagreement.
        SegmentedPicker(
            L("border.corner_style", "Corners"),
            selection: model.borderCornersMaster,
            options: [
                (
                    L("border.corner.rounded", "Rounded"),
                    BorderStyle.CornerStyle.rounded
                ),
                (
                    L("border.corner.square", "Square"),
                    BorderStyle.CornerStyle.square
                ),
            ],
            help: cornersHelp
        )
    }
}
