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
                        + "visible. With the Space Bar off, the "
                        + "menu bar shows the Space each screen is "
                        + "on.",
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
            Toggle(
                L("kiwishelf.show.space_bar", "Space Bar"),
                isOn: $model.config.settings.spaceBarStyle.enabled
            )
        case .layoutAppBar(.monocleAppBarEnabled):
            Toggle(
                SettingsCatalog.bars.monocleShowIn.text,
                isOn: $model.config.settings.monocle.appBar.enabled
            )
            .searchAnchored(SettingsCatalog.bars.monocleShowIn)
        case .layoutAppBar(.scrollingAppBarEnabled):
            Toggle(
                SettingsCatalog.bars.scrollingShowIn.text,
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
    /// bars at opposite ends, a Space Bar aligned elsewhere moves
    /// when the App Bar appears — Core's own verdict (#1517).
    private var alignmentNote: String? {
        guard gates.bothBarsShow else { return nil }
        switch ShelfArrangement.spaceBarMoves(shelf: shelf.wrappedValue) {
        case .start:
            return L(
                "kiwishelf.alignment.note.start",
                "While the App Bar shows, the two bars sit at "
                    + "opposite ends, so the Space Bar moves to the "
                    + "start. \u{201C}%1$@\u{201D} keeps it still.",
                L("app_bar.alignment.start", "Start")
            )
        case .end:
            return L(
                "kiwishelf.alignment.note.end",
                "While the App Bar shows, the two bars sit at "
                    + "opposite ends, so the Space Bar moves to the "
                    + "end. \u{201C}%1$@\u{201D} keeps it still.",
                L("app_bar.alignment.end", "End")
            )
        case .center, nil:
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
                active: gates.bothBarsReason != nil,
                help: gates.bothBarsReason.map(BarsGateHelp.sentence)
                    ?? ""
            )
        )
    }

    /// The share row is a split row: the same slider, readout and
    /// ¼…¾ chips, over the stored percent read as a fraction.
    /// The Space Bar's floor once the shelf is full (#1517): a
    /// minimum, not a split, so a slider and no quick picks.
    var minimumRow: some View {
        PtSlider(
            label: L("kiwishelf.minimum", "Space Bar minimum"),
            value: shelf.minimum,
            range: BarSliderBands.minimum,
            unit: "%",
            help: L(
                "kiwishelf.minimum.help",
                "Only matters once both bars together are longer "
                    + "than the edge: the Space Bar shrinks, but "
                    + "keeps at least this much of the edge, and "
                    + "the App Bar scrolls instead."
            )
        )
        .modifier(
            GreyOut(
                active: gates.bothBarsReason != nil,
                help: gates.bothBarsReason.map(BarsGateHelp.sentence)
                    ?? ""
            )
        )
    }
}
