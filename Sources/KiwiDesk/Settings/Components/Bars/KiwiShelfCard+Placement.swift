import KiwiDeskCore
import SwiftUI

/// The KiwiShelf card's Show group and the rows that place the
/// bars along the edge: alignment for a lone bar, order and share
/// once both show.
extension KiwiShelfCard {
    /// How each bar shows (#761) — the Space Bar in every layout,
    /// the App Bar only where a layout can carry one: always, until
    /// the pointer reaches its edge, or only on its shortcut.
    var showGroup: some View {
        SettingsRowShape {
            SettingsRowLabel(
                label: L("kiwishelf.show.label", "Show"),
                help: L(
                    "kiwishelf.show.visibility.help",
                    "Always keeps a bar on screen. Auto hides it "
                        + "to a thin mark until the pointer reaches "
                        + "its edge. Hidden draws nothing: its "
                        + "shortcut still shows it, over your "
                        + "windows. Only %1$@ and %2$@ can carry an "
                        + "App Bar. With the Space Bar hidden, the "
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
        case .spaceBar(.spaceBarVisibility):
            visibilityRow(
                L("kiwishelf.show.space_bar", "Space Bar"),
                $model.config.settings.spaceBarStyle.visibility
            )
            besideAlwaysNote(.space, in: [.monocle, .scrolling])
        case .spaceBar(.spaceCue):
            spaceCueRow
        case .layoutAppBar(.monocleAppBarVisibility):
            visibilityRow(
                SettingsCatalog.bars.monocleShowIn.text,
                $model.config.settings.monocle.appBar.visibility
            )
            .searchAnchored(SettingsCatalog.bars.monocleShowIn)
            besideAlwaysNote(.app, in: [.monocle])
        case .layoutAppBar(.scrollingAppBarVisibility):
            visibilityRow(
                SettingsCatalog.bars.scrollingShowIn.text,
                $model.config.settings.scrolling.appBar.visibility
            )
            .searchAnchored(SettingsCatalog.bars.scrollingShowIn)
            besideAlwaysNote(.app, in: [.scrolling])
        default:
            let _ = assertionFailure(
                "unrendered Show key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// Under an `auto` bar beside an `always` one on its edge: it
    /// stays shown there (#761) — Core's verdict, over the bars'
    /// own edges.
    @ViewBuilder private func besideAlwaysNote(
        _ bar: ShelfBar,
        in modes: [LayoutMode]
    ) -> some View {
        let settings = model.config.settings
        if modes.contains(where: {
            settings.autoReadsAlways(bar, in: $0, on: nil)
        }) {
            BarNoteRow(
                text: bar == .space
                    ? L(
                        "kiwishelf.show.space_bar.beside_always",
                        "Stays shown while an App Bar set to %1$@ "
                            + "shares its edge.",
                        L("bar.visibility.always", "Always")
                    )
                    : L(
                        "kiwishelf.show.app_bar.beside_always",
                        "Stays shown: the Space Bar on its edge is "
                            + "set to %1$@.",
                        L("bar.visibility.always", "Always")
                    )
            )
        }
    }

    /// One bar's Always · Auto · Hidden strip, named by `title`.
    private func visibilityRow(
        _ title: String,
        _ selection: Binding<ShelfVisibility>
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .accessibilityHidden(true)
            Spacer(minLength: 8)
            SegmentedPicker(
                spokenLabel: title,
                selection: selection,
                options: AppBarOptions.visibility.map { ($0.1, $0.0) }
            )
        }
    }

    @ViewBuilder var alignmentRow: some View {
        SegmentedPicker(
            L("kiwishelf.alignment.label", "Alignment"),
            selection: shelf.alignment,
            options: AppBarOptions.alignment.map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.alignment.label.help",
                "Where the bars sit along the edge — a lone bar, "
                    + "both as one run, or each bar on its own edge. "
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

    /// The accepted trade-off, said where it is chosen: once the
    /// App Bar joins the Space Bar into one run, a Space Bar
    /// aligned anywhere but the run's own end moves — Core's own
    /// verdict names the alignment that holds it still (#1517).
    private var alignmentNote: String? {
        guard model.config.settings.bothBarsCanShow,
            gates.bothBarsReason == nil,
            let steady = ShelfArrangement.spaceBarMoves(
                shelf: shelf.wrappedValue
            )
        else { return nil }
        return L(
            "kiwishelf.alignment.note",
            "When the App Bar shows, the two bars join into one "
                + "run, so the Space Bar moves. \u{201C}%1$@\u{201D} "
                + "keeps it still.",
            steady == .start
                ? L("app_bar.alignment.start", "Start")
                : L("app_bar.alignment.end", "End")
        )
    }

    var orderRow: some View {
        SegmentedPicker(
            L("kiwishelf.order.label", "Order"),
            selection: shelf.order,
            options: AppBarOptions.order.map { ($0.1, $0.0) },
            help: L(
                "kiwishelf.order.label.help",
                "While both bars show, they join into one run in "
                    + "this order."
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
