import KiwiDeskCore
import SwiftUI

/// The KiwiShelf card's Show group and the rows that place the
/// bars along the edge: alignment for a lone bar, order and share
/// once both show.
extension KiwiShelfCard {
    /// Which bars the shelf carries — the Space Bar in every
    /// layout, the App Bar only where a layout can carry one.
    var showGroup: some View {
        SettingsRowShape {
            SettingsRowLabel(
                label: L("kiwishelf.show.label", "Show"),
                help: L(
                    "kiwishelf.show.help",
                    "The Space Bar shows in every layout. Only "
                        + "%1$@ and %2$@ can carry an App Bar — "
                        + "the other layouts keep every window "
                        + "visible.",
                    L("layout.monocle.name", "Monocle"),
                    L("layout.scrolling.name", "Scrolling")
                )
            )
        } control: {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(BarsRowOrder.kiwishelfShow, id: \.id) {
                    row(for: $0)
                }
            }
        }
    }

    @ViewBuilder func showRow(_ key: SettingKey) -> some View {
        switch key {
        case .spaceBar(.spaceBarEnabled):
            HStack(spacing: 6) {
                Toggle(
                    L("kiwishelf.show.space_bar", "Space Bar"),
                    isOn: $model.config.settings.spaceBarStyle.enabled
                )
                Text(L("kiwishelf.show.every_layout", "every layout"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .layoutAppBar(.monocleAppBarEnabled):
            Toggle(
                L("kiwishelf.show.monocle", "App Bar in Monocle"),
                isOn: $model.config.settings.monocle.appBar.enabled
            )
            .searchAnchored(SettingsCatalog.bars.monocleShowIn)
        case .layoutAppBar(.scrollingAppBarEnabled):
            Toggle(
                L("kiwishelf.show.scrolling", "App Bar in Scrolling"),
                isOn: $model.config.settings.scrolling.appBar.enabled
            )
            .searchAnchored(SettingsCatalog.bars.scrollingShowIn)
        default:
            let _ = assertionFailure(
                "unrendered Show key: \(key.id)"
            )
            EmptyView()
        }
    }

    @ViewBuilder var alignmentRow: some View {
        SegmentedPicker(
            L("kiwishelf.alignment.label", "Alignment"),
            selection: shelf.alignment,
            options: AppBarOptions.alignment.map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.alignment.label.help",
                "Where a bar sits while it is the only one shown. "
                    + "\u{201C}%1$@\u{201D} and \u{201C}%2$@\u{201D} "
                    + "follow the edge, so on a left edge the start "
                    + "is the top.",
                L("app_bar.alignment.start", "Start"),
                L("app_bar.alignment.end", "End")
            )
        )
        if let note = alignmentNote {
            BarNoteRow(text: note)
        }
    }

    /// The accepted trade-off, said where it is chosen: with both
    /// bars at opposite ends, a centred Space Bar moves when the
    /// App Bar appears (#1517).
    private var alignmentNote: String? {
        let value = shelf.wrappedValue
        guard gates.bothBarsShow else { return nil }
        switch (value.order, value.alignment) {
        case (.spacesFirst, .center), (.spacesFirst, .end):
            return L(
                "kiwishelf.alignment.note.start",
                "While the App Bar shows, the two bars sit at "
                    + "opposite ends, so the Space Bar moves to the "
                    + "start. \u{201C}%1$@\u{201D} keeps it still.",
                L("app_bar.alignment.start", "Start")
            )
        case (.appsFirst, .start), (.appsFirst, .center):
            return L(
                "kiwishelf.alignment.note.end",
                "While the App Bar shows, the two bars sit at "
                    + "opposite ends, so the Space Bar moves to the "
                    + "end. \u{201C}%1$@\u{201D} keeps it still.",
                L("app_bar.alignment.end", "End")
            )
        default:
            return nil
        }
    }

    var orderRow: some View {
        SegmentedPicker(
            L("kiwishelf.order.label", "Order"),
            selection: shelf.order,
            options: AppBarOptions.order.map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.order.label.help",
                "While both bars show, they take opposite ends of "
                    + "the edge in this order."
            )
        )
        .modifier(
            GreyOut(
                active: !gates.bothBarsShow,
                help: BarsGateHelp.sentence(for: .oneBarShown)
            )
        )
    }

    var shareRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            PtSlider(
                label: L("kiwishelf.share", "Space Bar share"),
                value: shelf.share,
                range: shareBand,
                unit: "%",
                help: L(
                    "kiwishelf.share.help",
                    "Only matters once both bars are full: the Space "
                        + "Bar gets this share of the edge, the App "
                        + "Bar the rest, and each scrolls inside its "
                        + "own. A bar that needs less always gives "
                        + "the rest back."
                )
            )
            SettingsRowShape {
                BarRowIndent()
            } control: {
                ShareChips(share: shelf.share)
            }
        }
        .modifier(
            GreyOut(
                active: !gates.bothBarsShow,
                help: BarsGateHelp.sentence(for: .oneBarShown)
            )
        )
    }

    private var shareBand: ClosedRange<Double> {
        let range = KiwiShelf.shareRange
        return Double(range.lowerBound)...Double(range.upperBound)
    }
}

/// Quick picks for the Space Bar share: the common fractions.
private struct ShareChips: View {
    @Binding var share: CGFloat

    private static let fractions: [(String, CGFloat)] = [
        ("¼", 25), ("⅓", 33), ("½", 50), ("⅔", 67), ("¾", 75),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.fractions, id: \.1) { glyph, value in
                Button(glyph) { share = value }
                    .settingsActionButton()
                    .controlSize(.small)
                    .accessibilityLabel(
                        L(
                            "kiwishelf.share.fraction",
                            "Space Bar share (percent): %1$d",
                            Int(value)
                        )
                    )
            }
        }
    }
}
