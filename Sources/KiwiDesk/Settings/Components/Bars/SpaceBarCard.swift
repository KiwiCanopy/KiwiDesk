import KiwiDeskCore
import SwiftUI

/// Settings card for the Space Bar's own look (#678); where it
/// sits and whether it shows are the KiwiShelf card's (#1517).
struct SpaceBarCard: View {
    @ObservedObject var model: SettingsModel
    @State private var styleExpanded = false

    var style: Binding<SpaceBarStyle> {
        $model.config.settings.spaceBarStyle
    }
    private var gates: BarsGates {
        BarsGates(settings: model.config.settings)
    }
    /// The census container gate, resolved live to a reason.
    private var reason: BarsGates.InertReason? {
        gates.containerReason(for: .spaceBar)
    }
    private var allows: Bool { reason == nil }

    var body: some View {
        // Section header help provides the gate anchor (#527).
        SettingsSection(
            SettingsCatalog.bars.spaceBarCard,
            caption: cardCaption,
            help: reason.map(BarsGateHelp.sentence)
        ) {
            // Preview strip renders in BarsPanelPreview (#678).
            rows(BarsRowOrder.spaceBarAtRest)
            styleDisclosure
        }
    }

    /// Each row carries the container gate unless the census
    /// exempts it — parallel `GreyOut`s, never nested, so
    /// nothing compounds to 0.25.
    private func rows(_ keys: [SettingKey]) -> some View {
        ForEach(keys, id: \.id) { key in
            row(for: key)
                .modifier(
                    GreyOut(
                        active: !allows
                            && !key.placement
                                .exemptFromContainerGate,
                        help: BarsGateHelp.sentence(for: .spaceBarOff)
                    )
                )
        }
    }

    @ViewBuilder private func row(for key: SettingKey) -> some View {
        switch key {
        case .spaceBar(let k):
            spaceBarRow(k)
        default:
            let _ = assertionFailure(
                "unrendered Bars census key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// Style disclosure; inner rows carry the gate (#527).
    private var styleDisclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.bars.spaceBarStyle,
            isExpanded: $styleExpanded,
            scrollHoisted: true,
            summary: styleSummary
        ) {
            rows(BarsRowOrder.spaceBarStyle)
                .padding(.top, 8)
        }
    }

    private var cardCaption: String {
        L(
            "bars.space_bar.shelf_caption",
            "One item per Space — one bar per display, every "
                + "layout. KiwiShelf places it."
        )
    }

    private var styleSummary: String {
        L(
            "bars.style.space_bar.shelf_summary",
            "Indicator, symbol style, glyph cap, front app title "
                + "length, spring delay"
        )
    }
}
