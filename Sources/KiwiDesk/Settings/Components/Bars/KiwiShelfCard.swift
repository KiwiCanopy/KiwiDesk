import KiwiDeskCore
import SwiftUI

/// Settings card for the shelf the bars sit on (#1517): how the
/// bars show and where each hangs (#1731), grouped by bar (#3612),
/// what plays while one is out of view, how the two share an edge,
/// and the look they share. No container gate: a hidden
/// bar's shortcut still shows it, so its look always matters
/// (#761).
struct KiwiShelfCard: View {
    @ObservedObject var model: SettingsModel
    @State var eachExpanded = false
    @State var durationsExpanded = false
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
            Divider()
            outOfViewGroup
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(BarsRowOrder.kiwishelfPlacement, id: \.id) {
                    row(for: $0)
                }
                // Where the bars sit, then how deep the strip is.
                Divider()
                ForEach(BarsRowOrder.kiwishelfDepth, id: \.id) {
                    row(for: $0)
                }
                styleDisclosure
                marginsDisclosure
            }
        }
        // The card opens on All screens, as its own state would
        // (#3612).
        .onAppear { model.nav.barsScope = nil }
    }

    @ViewBuilder func row(for key: SettingKey) -> some View {
        switch key {
        case .kiwishelf(let k):
            kiwishelfRow(k)
        case .spaceBar(.spaceBarVisibility), .layoutAppBar:
            showRow(key)
        case .colours(.animationsOnReveal),
            .colours(.animationsOnExpand):
            durationRow(key)
        default:
            let _ = assertionFailure(
                "unrendered KiwiShelf census key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// What plays while a bar is out of view (#3612), under one
    /// heading: what the menu bar shows instead, the handle, how
    /// the bar comes back and how long that takes.
    private var outOfViewGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsGroupHeading(
                title: SettingsCatalog.bars.kiwishelfOutOfView.text
            )
            .searchAnchored(SettingsCatalog.bars.kiwishelfOutOfView)
            ForEach(BarsRowOrder.kiwishelfOutOfView, id: \.id) {
                row(for: $0)
            }
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
            "What both bars share — when they show, where they sit, "
                + "and how they look."
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
            "A look sets where the bars sit and how they look, "
                + "both indicators, the focus border's shape and "
                + "sheen, and the window gaps in one click — in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    private var marginsSummary: String {
        L("kiwishelf.margins.summary", "Outer and inner margin")
    }
}
