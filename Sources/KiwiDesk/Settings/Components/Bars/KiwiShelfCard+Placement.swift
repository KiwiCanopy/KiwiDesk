import KiwiDeskCore
import SwiftUI

/// The KiwiShelf card's head, its Show rows, and the rows that
/// place the bars along the edge once both show: order and share.
extension KiwiShelfCard {
    /// The card's head (#761, #2978, #3612): the Show and Position
    /// masters for every bar and the Pocket, each bar's own rows
    /// behind Each bar and Pocket — the Space Bar in every layout,
    /// the App Bar only where a layout can carry one, then the
    /// Pocket. A master selects nothing while they differ and says
    /// why through its `?`.
    var showGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(BarsRowOrder.kiwishelfShow, id: \.id) {
                row(for: $0)
            }
        }
    }

    var visibilitySplit: Bool {
        GapsBordersGates(settings: model.config.settings)
            .followersDiffer(for: .kiwishelf(.visibility))
    }

    var visibilityMasterHelp: String {
        model.config.settings.hasScreenVisibilities
            ? BarsGateHelp.visibilityDiffersPerScreen
            : visibilitySplit
                ? BarsGateHelp.visibilityDiffers
                : L(
                    "kiwishelf.show.visibility.help",
                    "Sets the bars and the Pocket together. Always "
                        + "keeps them on screen. Auto hides each to its "
                        + "handle until the pointer rests on it. "
                        + "Hidden shows a bar only through its "
                        + "shortcut, over your windows, and the Pocket "
                        + "only while a window goes in or out, while "
                        + "you drag one, or when its list's shortcut "
                        + "opens it. Only %1$@ and %2$@ can carry an "
                        + "App Bar. With \u{201C}%3$@\u{201D} left at its "
                        + "default, the menu bar shows the Space each "
                        + "screen is on wherever the Space Bar is hidden.",
                    L("layout.monocle.name", "Monocle"),
                    L("layout.scrolling.name", "Scrolling"),
                    L("kiwishelf.menu_bar_icon", "Menu bar icon")
                )
    }

    /// The Show master; Each bar and Pocket hangs under Position.
    var visibilityRows: some View {
        SegmentedPicker(
            L("kiwishelf.show.label", "Show"),
            selection: model.barVisibilityMaster,
            options: AppBarOptions.visibility.map { ($0.1, $0.0) },
            help: visibilityMasterHelp
        )
    }

    @ViewBuilder func showRow(_ key: SettingKey) -> some View {
        switch key {
        case .spaceBar(.spaceBarVisibility):
            visibilityRow(
                L("kiwishelf.show.label", "Show"),
                .spaceBar,
                model.barShowBinding(.spaceBar),
                help: model.screenShowsHelp(.spaceBar)
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfEach.children
                    .spaceBarShow
            )
            besideAlwaysNote(.space, in: [.monocle, .scrolling])
        case .layoutAppBar(.monocleAppBarVisibility):
            let maximizes = model.config.settings.maximizesWindows(
                in: .monocle
            )
            visibilityRow(
                Self.showIn(.monocle),
                .appBar,
                model.barShowBinding(.appBar(.monocle)),
                help: model.screenShowsHelp(.appBar(.monocle))
            )
            .modifier(GreyOut(active: maximizes))
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfEach.children
                    .monocleShowIn
            )
            if maximizes {
                monocleMaximizesNote
            } else {
                besideAlwaysNote(.app, in: [.monocle])
            }
        case .layoutAppBar(.scrollingAppBarVisibility):
            visibilityRow(
                Self.showIn(.scrolling),
                .appBar,
                model.barShowBinding(.appBar(.scrolling)),
                help: model.screenShowsHelp(.appBar(.scrolling))
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfEach.children
                    .scrollingShowIn
            )
            besideAlwaysNote(.app, in: [.scrolling])
        case .kiwishelf(.pocketVisibility):
            visibilityRow(
                L("kiwishelf.show.label", "Show"),
                .pocket,
                $model.config.settings.kiwishelf.pocketVisibility,
                options: AppBarOptions.pocketVisibility
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfEach.children
                    .pocketShow
            )
            autoPocketNote
        case .kiwishelf(.pocketDragReveal):
            ToggleRow(
                label: SettingsCatalog.bars.kiwishelfEach.children
                    .pocketDragReveal.text,
                isOn: $model.config.settings.kiwishelf.pocketDragReveal,
                // Greyed under a picked area, its `?` the block's.
                help: activeScope != nil
                    ? nil
                    : L(
                        "kiwishelf.show.pocket_drag.help",
                        "Off, a drag leaves the Pocket hidden. Its keys "
                            + "and list still reach it."
                    )
            )
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfEach.children
                    .pocketDragReveal
            )
        default:
            let _ = assertionFailure(
                "unrendered Show key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// An App Bar Show row's label under its bar's name (#3612).
    static func showIn(_ mode: LayoutMode) -> String {
        L("kiwishelf.show.app_bar_in", "Show in %1$@", mode.displayName)
    }

    /// Under the App Bar in Monocle while Monocle maximizes its
    /// windows: the row has no effect at rest there, so it greys
    /// and links to the switch (#2976 ▸ 6).
    private var monocleMaximizesNote: some View {
        CrossReferenceRow(
            prose: Self.monocleMaximizesProse,
            linkTitle: SettingsDestination.layoutDefaults.title,
            destination: .layoutDefaults
        )
        .font(.caption)
    }

    /// The link line's sentence, its link at the slot.
    static var monocleMaximizesProse: String {
        L(
            "kiwishelf.show.monocle.maximizes_link",
            "Hidden at rest while \u{201C}%1$@\u{201D} is on for %2$@ "
                + "in %3$@.",
            LayoutHelp.monocleMaximizeWindowsLabel,
            L("layout.monocle.name", "Monocle"),
            CrossReferenceRow.linkSlot
        )
    }

    /// Under an `auto` bar beside an `always` one on its edge: it
    /// stays shown there (#761) — Core's verdict, on any screen's
    /// edges (`screenVariants`).
    @ViewBuilder private func besideAlwaysNote(
        _ bar: ShelfBar,
        in modes: [LayoutMode]
    ) -> some View {
        let screens = model.config.settings.screenVariants
        if screens.contains(where: { screen in
            modes.contains {
                screen.autoReadsAlways(bar, in: $0, on: nil)
            }
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

    /// Under an Auto Pocket on the edge of a bar shown at rest: it
    /// stays shown there (#2978) — Core's verdict, on any screen's
    /// edges in any layout.
    @ViewBuilder private var autoPocketNote: some View {
        let screens = model.config.settings.screenVariants
        if screens.contains(where: { screen in
            LayoutMode.allCases.contains {
                screen.barKeepsAutoPocket(in: $0, on: nil)
            }
        }) {
            BarNoteRow(
                text: L(
                    "kiwishelf.show.pocket.beside_always",
                    "On %1$@, the Pocket stays shown while a bar on its "
                        + "edge is set to %2$@.",
                    L("kiwishelf.show.pocket.auto", "Auto"),
                    L("bar.visibility.always", "Always")
                )
            )
        }
    }

    /// One bar's Always · Auto · Hidden strip, on the shared label
    /// axis like every labelled picker (#2439), spoken with its
    /// block's name (#3612).
    private func visibilityRow(
        _ title: String,
        _ block: ShelfBlock,
        _ selection: Binding<ShelfVisibility>,
        options: [(ShelfVisibility, String)] = AppBarOptions.visibility,
        help: String? = nil
    ) -> some View {
        SegmentedPicker(
            title,
            spokenLabel: block.spoken(title),
            selection: selection,
            options: options.map { ($0.1, $0.0) },
            help: help
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
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleOrder
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
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleMinimum
        )
    }
}
