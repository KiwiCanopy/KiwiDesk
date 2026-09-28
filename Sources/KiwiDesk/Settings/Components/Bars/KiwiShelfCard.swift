import KiwiDeskCore
import SwiftUI

/// Settings card for the shelf the bars sit on (#1517): which
/// bars it shows, where each hangs (#1731), how the two share an
/// edge, and the look they share. No container gate — the Show rows that
/// switch the bars on live here — so every other row greys as a
/// block while no bar shows (`BarsGates.shelfShows`).
struct KiwiShelfCard: View {
    @ObservedObject var model: SettingsModel
    @State var edgesExpanded = false
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
            // A look writes this card's style in one click (#1684).
            CrossReferenceRow(
                prose: Self.lookReference,
                linkTitle: SettingsDestination.looks.title,
                destination: .looks
            )
            showGroup
            VStack(alignment: .leading, spacing: 8) {
                ForEach(BarsRowOrder.kiwishelfAtRest, id: \.id) {
                    row(for: $0)
                }
                styleDisclosure
                marginsDisclosure
            }
            .modifier(
                GreyOut(
                    active: !gates.shelfShows,
                    help: BarsGateHelp.sentence(for: .shelfEmpty)
                )
            )
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
            "One place for both bars: where each sits, how they "
                + "share an edge, and the style they have in common."
        )
    }

    private var styleSummary: String {
        L(
            "bars.style.kiwishelf.summary",
            "Background, roundness, item gap, font size"
        )
    }

    static var lookReference: String {
        L(
            "bars.kiwishelf.looks_xref",
            "A look sets this card's style, both indicators and "
                + "the focus border's sheen in one click — in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    private var marginsSummary: String {
        L("kiwishelf.margins.summary", "Outer and inner margin")
    }
}
