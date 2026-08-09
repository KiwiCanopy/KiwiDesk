import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Gaps & Borders ▸ Shared by all borders (#754):
/// the decisions all three strokes share, above the sections
/// that draw them.
///
/// KiwiDesk strokes three things — the focus ring, the drag
/// ghost and the drop zone — and in practice a user picks one
/// look and wants all three to match it. Asked three times, two
/// of the three answers are simply forgotten, so a 3 pt ring
/// beside a 1 pt ghost is not a preference anyone holds. The
/// answer is to REMOVE the decision, not to build a control that
/// protects it: these two rows are the page's only width and
/// corner questions, and they write every stroke.
///
/// The card is titled for what it DECIDES rather than for the
/// thing it decides about — "Borders" would read as a fourth
/// section competing with Focus border and Drag & drop, and sits
/// one letter from the `border.*` family whose own title is
/// "Focus border".
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

    /// A master writes over whatever the strokes hold now, and
    /// Lua can leave them holding three different things. The
    /// gap masters answer that by greying; these cannot, having
    /// no per-stroke row to send anyone to (`GapsBordersGates`
    /// carries the argument), so they say it instead — a `?`
    /// that appears exactly while the disagreement does.
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
        // One domain for all three strokes, and it starts at 1:
        // a stroke of no width is what each drag column's own
        // Border toggle already says, and the focus ring has its
        // own Show focus border. A 0 on this slider would be a
        // third way to say "off" that turns off all three.
        PtSlider(
            label: L("border.width", "Width"),
            value: model.borderWidthMaster,
            range: 1...20,
            help: widthHelp
        )
        // Optional-valued on purpose: neither option is `nil`,
        // so a ring style and a drag radius that disagree match
        // no segment and the pill hides itself
        // (`SegmentedPickerUnmatchedTests`). Whichever segment
        // is then tapped ends the disagreement.
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
