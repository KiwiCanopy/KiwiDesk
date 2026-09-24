import KiwiDeskCore
import SwiftUI

/// Settings card for the shelf both bars sit on (#1517): which
/// bars it shows, where it hangs, how the two share the edge, and
/// the look they share. No container gate — the Show rows that
/// switch the bars on live here.
struct KiwiShelfCard: View {
    @ObservedObject var model: SettingsModel
    @State private var styleExpanded = false
    @State private var marginsExpanded = false

    var shelf: Binding<KiwiShelf> {
        $model.config.settings.kiwishelf
    }
    var gates: BarsGates {
        BarsGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.bars.kiwishelfCard,
            caption: cardCaption
        ) {
            showGroup
            ForEach(BarsRowOrder.kiwishelfAtRest, id: \.id) { key in
                row(for: key)
            }
            styleDisclosure
            marginsDisclosure
        }
    }

    @ViewBuilder func row(for key: SettingKey) -> some View {
        switch key {
        case .kiwishelf(let k):
            kiwishelfRow(k)
        case .spaceBar(.spaceBarEnabled), .layoutAppBar:
            showRow(key)
        default:
            let _ = assertionFailure(
                "unrendered KiwiShelf census key: \(key.id)"
            )
            EmptyView()
        }
    }

    private var styleDisclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.bars.kiwishelfStyle,
            isExpanded: $styleExpanded,
            scrollHoisted: true,
            summary: styleSummary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(BarsRowOrder.kiwishelfStyle, id: \.id) {
                    row(for: $0)
                }
            }
            .padding(.top, 8)
        }
    }

    private var marginsDisclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.bars.kiwishelfMargins,
            isExpanded: $marginsExpanded,
            scrollHoisted: true,
            summary: marginsSummary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(BarsRowOrder.kiwishelfMargins, id: \.id) {
                    row(for: $0)
                }
            }
            .padding(.top, 8)
        }
    }

    private var cardCaption: String {
        L(
            "bars.kiwishelf.caption",
            "Where both bars sit — which edge, how deep, and how "
                + "the two share the room."
        )
    }

    private var styleSummary: String {
        L(
            "bars.style.kiwishelf.summary",
            "Background, roundness, item gap, font size"
        )
    }

    private var marginsSummary: String {
        L("kiwishelf.margins.summary", "Outer and inner margin")
    }
}
