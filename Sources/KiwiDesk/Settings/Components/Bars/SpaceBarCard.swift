import KiwiDeskCore
import SwiftUI

/// Settings card for the Space Bar's own look (#678); where it
/// sits and whether it shows are the KiwiShelf card's (#1517).
struct SpaceBarCard: View {
    @ObservedObject var model: SettingsModel
    @State private var tuningExpanded = false

    var style: Binding<SpaceBarStyle> {
        $model.config.settings.spaceBarStyle
    }
    private var gates: BarsGates {
        BarsGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.bars.spaceBarCard,
            caption: cardCaption
        ) {
            // Preview strip renders in BarsPanelPreview (#678).
            rows(BarsRowOrder.spaceBar)
            tuningDisclosure
        }
    }

    /// The numbers, in one drawer at the card's foot (#2507).
    private var tuningDisclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.bars.spaceBarTuning,
            isExpanded: $tuningExpanded,
            scrollHoisted: true,
            summary: L(
                "space_bar.fine_tuning.summary",
                "Title length, glyphs, spring delay"
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                rows(BarsRowOrder.spaceBarTuning)
            }
            .padding(.top, 8)
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
        case .spaceBar(let k):
            spaceBarRow(k)
        default:
            let _ = assertionFailure(
                "unrendered Bars census key: \(key.id)"
            )
            EmptyView()
        }
    }

    private var cardCaption: String {
        L(
            "bars.space_bar.shelf_caption",
            "One item per Space — one bar per screen, every "
                + "layout. KiwiShelf places this bar."
        )
    }
}
