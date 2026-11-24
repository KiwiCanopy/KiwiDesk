import KiwiDeskCore
import SwiftUI

/// Each bar and Pocket (#3612): a Screen or area picker, then one
/// block per bar editing what it picks — under All screens each
/// bar's own values, else that screen's or area's. The Pocket's
/// every-screen rows grey while an area is picked, the picker being
/// the switch that brings them back.
extension KiwiShelfCard {
    /// Held open only while the bars' own Show or Position differ:
    /// a screen's or area's value is counted in the summary instead.
    var eachHeldOpen: Bool {
        let settings = model.config.settings
        return settings.ownBarVisibility == nil
            || settings.ownShelfEdge == nil
    }

    /// The picked screen or area, nil for All screens — also while
    /// the pick has left the list.
    var activeScope: String? {
        guard let scope = model.nav.barsScope, model.offersScreenScopes,
            model.screenScopes.contains(where: { $0.id == scope })
        else { return nil }
        return scope
    }

    var eachDrawer: some View {
        let own = model.screenScopes.filter { model.hasOwnSettings($0.id) }
        return SettingsDisclosure(
            SettingsCatalog.bars.kiwishelfEach,
            chrome: .attached,
            isExpanded: $eachExpanded,
            scrollHoisted: true,
            summary: own.isEmpty
                ? nil
                : L(
                    "kiwishelf.scope.summary",
                    "Own settings: %1$d",
                    own.count
                ),
            locked: eachHeldOpen
        ) {
            // Spelled out in `BarsRowOrder.kiwishelfEach`' order:
            // `row(for:)` renders the row holding this drawer, and an
            // opaque type cannot contain itself.
            VStack(alignment: .leading, spacing: 16) {
                scopeRows(own)
                spaceBarBlock
                appBarBlock
                pocketBlock
            }
            .padding(.top, 8)
        }
    }

    /// The picker and, under All screens, which areas it misses.
    @ViewBuilder private func scopeRows(_ own: [ScreenEdgeRow]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            scopePicker
            if activeScope == nil, !own.isEmpty {
                note(
                    L(
                        "kiwishelf.scope.keep_own",
                        "Own settings: %1$@",
                        LocalizedList.join(own.map(\.name))
                    )
                )
            }
        }
        // A hit on any per-area setting lands on the picker.
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children
                .kiwishelfSpaceBarScreenEdges
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children
                .kiwishelfSpaceBarScreenShows
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children
                .kiwishelfAppBarScreenEdges
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children
                .kiwishelfMonocleScreenShows
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children
                .kiwishelfScrollingScreenShows
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children
                .kiwishelfPocketScreenEdges
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfEach.children.screenOrArea
        )
    }

    private var scopePicker: some View {
        let offered = model.offersScreenScopes
        let scopes = model.screenScopes
        let label = SettingsCatalog.bars.kiwishelfEach.children
            .screenOrArea.text
        let all = L("kiwishelf.scope.all", "All screens")
        let picked = scopes.first { $0.id == activeScope }
        return DropdownRow(
            label: label,
            spokenValue: picked.map {
                Self.scopeTitle($0, own: model.hasOwnSettings($0.id))
            } ?? all,
            help: offered ? Self.scopeHelp : Self.oneScreenHelp
        ) {
            Picker(label, selection: scopeBinding) {
                Text(all).tag(String?.none)
                Divider()
                ForEach(scopes) { row in
                    Text(
                        Self.scopeTitle(row, own: model.hasOwnSettings(row.id))
                    )
                    .tag(Optional(row.id))
                }
            }
            .modifier(GreyOut(active: !offered))
        }
    }

    /// The picker's selection: what the blocks edit, so a pick that
    /// has left the list reads as All screens.
    private var scopeBinding: Binding<String?> {
        Binding(
            get: { activeScope },
            // A greyed pop-up still takes a pick (gui.md).
            set: { pick in
                guard model.offersScreenScopes else { return }
                model.nav.barsScope = pick
            }
        )
    }

    /// An item's words: its name, its twins, its absence, and
    /// whether it holds values of its own.
    static func scopeTitle(_ row: ScreenEdgeRow, own: Bool) -> String {
        var title =
            row.count > 1
            ? L("kiwishelf.scope.twins", "%1$@ × %2$d", row.name, row.count)
            : row.name
        if !row.present {
            title = L(
                "kiwishelf.edge.screen.absent_name",
                "%1$@, %2$@",
                title,
                L("kiwishelf.edge.screen.absent", "not connected")
            )
        }
        guard own else { return title }
        return L("kiwishelf.scope.own", "%1$@ — own settings", title)
    }

    private var spaceBarBlock: some View {
        barGroup(L("kiwishelf.bar.space_bar", "Space Bar")) {
            if let key = activeScope {
                areaShow(.spaceBar, Self.showLabel, on: key, bar: .spaceBar)
                areaEdge(\.spaceBarStyle, on: key, bar: .spaceBar)
            } else {
                showRow(.spaceBar(.spaceBarVisibility))
                spaceBarEdgeRow
            }
        }
    }

    private var appBarBlock: some View {
        barGroup(L("kiwishelf.bar.app_bar", "App Bar")) {
            if let key = activeScope {
                areaShow(
                    .appBar(.monocle),
                    Self.showIn(.monocle),
                    on: key,
                    bar: .appBar
                )
                areaShow(
                    .appBar(.scrolling),
                    Self.showIn(.scrolling),
                    on: key,
                    bar: .appBar
                )
                areaEdge(\.appBarStyle, on: key, bar: .appBar)
            } else {
                showRow(.layoutAppBar(.monocleAppBarVisibility))
                showRow(.layoutAppBar(.scrollingAppBarVisibility))
                appBarEdgeRow
            }
        }
    }

    private var pocketBlock: some View {
        let scoped = activeScope != nil
        return barGroup(L("kiwishelf.bar.pocket", "Pocket")) {
            everyScreen(scoped) { showRow(.kiwishelf(.pocketVisibility)) }
            everyScreen(scoped) { showRow(.kiwishelf(.pocketDragReveal)) }
            if let key = activeScope {
                areaEdge(\.kiwishelf.pocketEdges, on: key, bar: .pocket)
            } else {
                pocketEdgeRow
            }
            everyScreen(scoped) { pocketPositionRows }
        }
    }

    /// A Pocket row with one value for every screen: greyed while an
    /// area is picked, its live `?` outside the grey (#527).
    @ViewBuilder private func everyScreen<Row: View>(
        _ scoped: Bool,
        @ViewBuilder _ row: () -> Row
    ) -> some View {
        if scoped {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 8) { row() }
                    .modifier(
                        GreyOut(active: true, help: Self.everyScreenHelp)
                    )
                HelpButton(explanation: Self.everyScreenHelp)
            }
        } else {
            row()
        }
    }

    /// The picked area's Show: Always, Auto or Hidden, and for a
    /// layout's App Bar Inherit first, which follows that layout's
    /// own (#3618).
    private func areaShow(
        _ row: BarShowRow,
        _ label: String,
        on key: String,
        bar: ShelfBlock
    ) -> some View {
        SegmentedPicker(
            label,
            spokenLabel: bar.spoken(label),
            selection: model.screenShowBinding(row, on: key),
            options: SettingsModel.screenShowOptions(row)
                .map { ($0.1, $0.0) },
            help: row.isAppBar ? Self.inheritHelp : nil
        )
    }

    /// What a layout's Inherit follows, on its row's `?`.
    private static var inheritHelp: String {
        L(
            "kiwishelf.show.screen.app_bar.inherit.help",
            "Inherit follows this layout's Show under All screens."
        )
    }

    private static var showLabel: String {
        L("kiwishelf.show.label", "Show")
    }

    /// The picked area's edge for `edged`.
    private func areaEdge<Bar: ScreenEdged>(
        _ edged: WritableKeyPath<TilingSettings, Bar>,
        on key: String,
        bar: ShelfBlock
    ) -> some View {
        let label = L("kiwishelf.edge.label", "Position")
        return SegmentedPicker(
            label,
            spokenLabel: bar.spoken(label),
            selection: model.screenEdge(edged, on: key),
            options: edgeOptions
        )
    }

    /// One bar's block in Each bar and Pocket: its name as a
    /// heading, then its rows.
    private func barGroup<Rows: View>(
        _ name: String,
        @ViewBuilder _ rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.body.weight(.semibold))
                .foregroundStyle(SettingsTheme.ink)
                .accessibilityAddTraits(.isHeader)
            rows()
        }
    }
}
