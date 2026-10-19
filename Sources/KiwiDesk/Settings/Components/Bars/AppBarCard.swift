import KiwiDeskCore
import SwiftUI

/// Settings card for the App Bar's own look; where it sits and
/// which layouts show it are the KiwiShelf card's (#1517).
struct AppBarCard: View {
    @ObservedObject var model: SettingsModel

    var style: Binding<AppBarStyle> {
        $model.config.settings.appBarStyle
    }
    var gates: BarsGates {
        BarsGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.bars.appBarCard,
            caption: cardCaption
        ) {
            // Preview strip renders in BarsPanelPreview (#678).
            rows(BarsRowOrder.appBar)
        }
    }

    /// The card's rows, in census order; none greys, since a
    /// hidden bar's shortcut still shows it (#761).
    private func rows(_ keys: [SettingKey]) -> some View {
        ForEach(keys, id: \.id) { key in
            row(for: key)
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

    private var cardCaption: String {
        L(
            "bars.app_bar.shelf_caption",
            "The windows in the current Space — %1$@ and %2$@ "
                + "only. KiwiShelf places this bar.",
            L("layout.monocle.name", "Monocle"),
            L("layout.scrolling.name", "Scrolling")
        )
    }
}
