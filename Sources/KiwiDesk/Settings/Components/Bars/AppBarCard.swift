import KiwiDeskCore
import SwiftUI

/// Settings card for the App Bar's own look; where it sits and
/// which layouts show it are the KiwiShelf card's (#1517).
struct AppBarCard: View {
    @ObservedObject var model: SettingsModel
    @State private var styleExpanded = false

    var style: Binding<AppBarStyle> {
        $model.config.settings.appBarStyle
    }
    var gates: BarsGates {
        BarsGates(settings: model.config.settings)
    }
    /// The census container gate, resolved live to a reason.
    private var reason: BarsGates.InertReason? {
        gates.containerReason(for: .appBar)
    }
    private var allows: Bool { reason == nil }

    var body: some View {
        // Section header help provides the gate anchor (#527).
        SettingsSection(
            SettingsCatalog.bars.appBarCard,
            caption: cardCaption,
            help: reason.map(BarsGateHelp.sentence)
        ) {
            // Preview strip renders in BarsPanelPreview (#678).
            rows(BarsRowOrder.appBarAtRest)
            styleDisclosure
        }
    }

    /// Parallel per-row gates (#520), respecting census exemptions.
    private func rows(_ keys: [SettingKey]) -> some View {
        ForEach(keys, id: \.id) { key in
            row(for: key)
                .modifier(
                    GreyOut(
                        active: !allows
                            && !key.placement
                                .exemptFromContainerGate,
                        help: BarsGateHelp.sentence(for: .noBarShown)
                    )
                )
        }
    }

    @ViewBuilder private func row(for key: SettingKey) -> some View {
        switch key {
        case .appBar(let k):
            appBarRow(k)
        default:
            let _ = assertionFailure(
                "unrendered Bars census key: \(key.id)"
            )
            EmptyView()
        }
    }

    private var styleDisclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.bars.appBarStyle,
            isExpanded: $styleExpanded,
            scrollHoisted: true,
            summary: styleSummary
        ) {
            rows(BarsRowOrder.appBarStyle)
                .padding(.top, 8)
        }
    }

    private var cardCaption: String {
        L(
            "bars.app_bar.shelf_caption",
            "The windows in the current Space — %1$@ and %2$@ "
                + "only. KiwiShelf places this bar.",
            L("layout.monocle.name", "Monocle"),
            L("layout.scrolling.name", "Scrolling")
        )
    }

    private var styleSummary: String {
        L(
            "bars.style.app_bar.shelf_summary",
            "Indicator, content, title length, symbol style"
        )
    }
}
