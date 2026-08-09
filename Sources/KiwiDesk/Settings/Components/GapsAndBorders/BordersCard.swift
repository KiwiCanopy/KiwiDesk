import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Gaps & Borders ▸ Borders (#754): the decisions
/// all three strokes share, above the sections that draw them.
///
/// KiwiDesk strokes three things — the focus ring, the drag
/// ghost and the drop zone — and in practice a user picks one
/// look and wants all three to match it. Asked three times, two
/// of the three answers are simply forgotten, so a 3 pt ring
/// beside a 1 pt ghost is not a preference anyone holds. The
/// link makes the shared answer the default one and leaves the
/// per-stroke sliders reachable, greyed rather than gone (#171).
///
/// The link toggle leads because it says what the two sliders
/// below it MEAN — with it off they are the ring's width and the
/// drag pair's radius, nothing more (topic grouping, gui.md).
struct BordersCard: View {
    @ObservedObject var model: SettingsModel

    private var linked: Binding<Bool> {
        Binding(
            get: { model.borderWidthLinked },
            set: { model.setBorderWidthLinked($0) }
        )
    }

    private var caption: String {
        L(
            "borders.caption",
            "The focus ring, the drag ghost and the drop zone "
                + "are strokes KiwiDesk draws around a window."
        )
    }

    private var linkLabel: String {
        L("border.link_width", "Use one width for all borders")
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.gapsAndBorders.bordersCard,
            caption: caption
        ) {
            Toggle(linkLabel, isOn: linked)
            Divider()
            masters
        }
    }

    @ViewBuilder private var masters: some View {
        PtSlider(
            label: L("border.width", "Width"),
            value: model.borderWidthMaster,
            range: 1...20
        )
        PtSlider(
            label: L("drag.corner_radius", "Corner radius"),
            value: model.borderCornerMaster,
            range: 0...40
        )
    }
}
