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
        let s = model.config.settings
        let shows =
            [s.spaceBarStyle.visibility] + s.appBarHosts.map(\.visibility)
            + [s.kiwishelf.pocketVisibility]
        return Set(shows).count > 1 || s.sharedBarEdge == nil
            || s.kiwishelf.pocketEdge != s.sharedBarEdge
    }

    /// The picked screen or area, nil for All screens — also while
    /// the pick has left the list.
    var activeScope: String? {
        guard let scope, model.offersScreenScopes,
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
                        "These keep their own settings: %1$@",
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
                .kiwishelfAppBarScreenShows
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
            spokenValue: picked.map(Self.scopeTitle) ?? all,
            help: offered ? Self.scopeHelp : Self.oneScreenHelp
        ) {
            Picker(label, selection: $scope) {
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

    /// An item's words: its name, its twins, its absence, and
    /// whether it holds values of its own.
    static func scopeTitle(_ row: ScreenEdgeRow) -> String {
        scopeTitle(row, own: false)
    }

    static func scopeTitle(_ row: ScreenEdgeRow, own: Bool) -> String {
        var title = row.count > 1 ? "\(row.name) × \(row.count)" : row.name
        if !row.present {
            title = L(
                "kiwishelf.edge.screen.ax_absent",
                "%1$@, %2$@",
                title,
                L("kiwishelf.edge.screen.absent", "not connected")
            )
        }
        guard own else { return title }
        return L("kiwishelf.scope.own", "%1$@ — own settings", title)
    }

    static var scopeHelp: String {
        L(
            "kiwishelf.scope.help",
            "\u{201C}%1$@\u{201D} sets each bar's own Show and Position. "
                + "Pick a screen or area to give it its own; picking "
                + "a bar's own value there stores nothing.",
            L("kiwishelf.scope.all", "All screens")
        )
    }

    static var oneScreenHelp: String {
        L(
            "kiwishelf.edge.per_screen.one_screen_or_split",
            "Needs a profile with two or more screens, or a screen "
                + "split into areas."
        )
    }

    /// The `?` and hover of a Pocket row that has one value for
    /// every screen, greyed while an area is picked.
    static var everyScreenHelp: String {
        L(
            "kiwishelf.scope.every_screen",
            "Applies on every screen. Choose \u{201C}%1$@\u{201D} above "
                + "to change it.",
            L("kiwishelf.scope.all", "All screens")
        )
    }

    private var spaceBarBlock: some View {
        barGroup(L("kiwishelf.bar.space_bar", "Space Bar")) {
            if let key = activeScope {
                areaShow(.space, on: key, bar: .spaceBar)
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
                areaShow(.app, on: key, bar: .appBar)
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

    /// The picked area's Show: Always, Auto or Hidden, and for the
    /// App Bar Per layout first, which follows each layout's own.
    private func areaShow(
        _ show: ScreenShowBar,
        on key: String,
        bar: ShelfBlock
    ) -> some View {
        let label = L("kiwishelf.show.label", "Show")
        return SegmentedPicker(
            label,
            spokenLabel: bar.spoken(label),
            selection: model.screenShowBinding(show, on: key),
            options: SettingsModel.screenShowOptions(show)
                .map { ($0.1, $0.0) }
        )
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

/// A block in Each bar and Pocket, whose name VoiceOver hears with
/// each of its controls ("Space Bar, Show").
enum ShelfBlock {
    case spaceBar
    case appBar
    case pocket

    @MainActor var name: String {
        switch self {
        case .spaceBar: L("kiwishelf.bar.space_bar", "Space Bar")
        case .appBar: L("kiwishelf.bar.app_bar", "App Bar")
        case .pocket: L("kiwishelf.bar.pocket", "Pocket")
        }
    }

    @MainActor func spoken(_ control: String) -> String {
        L("kiwishelf.per_screen.control.ax", "%1$@, %2$@", name, control)
    }
}
