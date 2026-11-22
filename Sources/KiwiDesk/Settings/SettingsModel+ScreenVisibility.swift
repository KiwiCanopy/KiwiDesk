import KiwiDeskCore
import SwiftUI

/// Which bar a Per screen row's Show menu writes (#3517 ruling
/// 30): the Space Bar's one visibility, or the App Bar's, which
/// each layout holds for itself.
enum ScreenShowBar {
    case space
    case app
}

/// A bar's own Show row: the Space Bar's, or one layout's App Bar's.
enum BarShowRow {
    case spaceBar
    case appBar(WritableKeyPath<TilingSettings, LayoutAppBar>)
}

/// The Show menu in a bar's Per screen rows (#3517 ruling 30): an
/// area's own visibility, keyed by its `ScreenAreaKey` — an unsplit
/// screen by its fingerprint.
extension SettingsModel {
    /// What `key` shows for `bar`: its own value, else the Space
    /// Bar's own; nil for an App Bar area with no value of its own,
    /// which follows each layout.
    func screenShow(_ bar: ScreenShowBar, on key: String) -> ShelfVisibility? {
        let settings = config.settings
        switch bar {
        case .space:
            return settings.spaceBarStyle.visibilityOverride[key]
                ?? settings.spaceBarStyle.visibility
        case .app:
            return settings.appBarStyle.visibilityOverride[key]
        }
    }

    /// The menu's binding: the Space Bar's own value stores nothing
    /// for the area; the App Bar's nil, Per layout, clears it. A
    /// pick needs the rows offered, since a greyed `.menu` picker
    /// still takes one (gui.md).
    func screenShowBinding(
        _ bar: ScreenShowBar,
        on key: String
    ) -> Binding<ShelfVisibility?> {
        Binding(
            get: { self.screenShow(bar, on: key) },
            set: { value in
                guard self.offersScreenShows(bar) else { return }
                var next = self.config.settings
                switch bar {
                case .space:
                    guard let value else { return }
                    next.spaceBarStyle.setVisibility(value, on: key)
                case .app:
                    next.appBarStyle.setVisibility(value, on: key)
                }
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }

    /// Whether `bar`'s Per screen rows take a Show pick: the edge
    /// drawer's own offer for that bar.
    private func offersScreenShows(_ bar: ScreenShowBar) -> Bool {
        switch bar {
        case .space: offersScreenEdges(\.spaceBarStyle, show: .space)
        case .app: offersScreenEdges(\.appBarStyle, show: .app)
        }
    }

    /// A bar's own Show row — the Space Bar's, or a layout's App
    /// Bar's — whose pick clears that bar's per-screen and per-area
    /// values through Core's doors (#3517 ruling 32), as a bar's
    /// edge pick clears its screens' edges.
    func barShowBinding(_ row: BarShowRow) -> Binding<ShelfVisibility> {
        Binding(
            get: {
                switch row {
                case .spaceBar:
                    self.config.settings.spaceBarStyle.visibility
                case .appBar(let layout):
                    self.config.settings[keyPath: layout].visibility
                }
            },
            set: { value in
                var next = self.config.settings
                switch row {
                case .spaceBar: next.spaceBarStyle.setVisibility(value)
                case .appBar(let layout):
                    next.setLayoutAppBarVisibility(value, in: layout)
                }
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }

    /// Whether `bar` gives some screen or area a visibility of its
    /// own, which holds its Per screen drawer open.
    func hasScreenShows(_ bar: ScreenShowBar) -> Bool {
        switch bar {
        case .space:
            !config.settings.spaceBarStyle.visibilityOverride.isEmpty
        case .app:
            !config.settings.appBarStyle.visibilityOverride.isEmpty
        }
    }

    /// A bar Show row's `?` while some screen or area shows `bar`
    /// its own way, which a pick there clears.
    func screenShowsHelp(_ bar: ScreenShowBar) -> String? {
        hasScreenShows(bar) ? BarsGateHelp.screenShowsDiffer : nil
    }

    /// The Show menu's choices for `bar`: the App Bar's Per layout,
    /// which stores nothing, leads its three values.
    static func screenShowOptions(
        _ bar: ScreenShowBar
    ) -> [(ShelfVisibility?, String)] {
        let values = AppBarOptions.visibility.map {
            (Optional($0.0), $0.1)
        }
        guard bar == .app else { return values }
        return [(nil, perLayout)] + values
    }

    /// A Per screen row's name, and its diff row's: `screen`, and on
    /// a split screen its area's place in reading order, every area
    /// numbered — interim until the positional area names (#3517).
    static func perScreenName(
        screen: String,
        key: String,
        splits: [String: ScreenSplit]
    ) -> String {
        let area = ScreenAreaKey(parsing: key)
        let keys = ScreenSplit.areaKeys(of: area.fingerprint, in: splits)
        guard keys.count > 1 || area.areaID != 0 else { return screen }
        let place = keys.firstIndex(of: key) ?? area.areaID
        return L(
            "kiwishelf.per_screen.area_name",
            "%1$@ – Area %2$@",
            screen,
            String(place + 1)
        )
    }

    /// The App Bar's "no value of its own" choice.
    static var perLayout: String {
        L("kiwishelf.show.screen.app_bar.per_layout", "Per layout")
    }
}
