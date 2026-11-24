import KiwiDeskCore
import SwiftUI

/// Which bar a picked area's Show writes (#3517 ruling 30,
/// #3612): the Space Bar's one visibility, or the App Bar's, which
/// each layout holds for itself.
enum ScreenShowBar {
    case space
    case app
}

/// A bar's own Show row: the Space Bar's, or one layout's App Bar's.
enum BarShowRow {
    case spaceBar
    case appBar(LayoutMode)
}

/// A bar's Show for a picked screen or area (#3517 ruling 30,
/// #3612): an area's own visibility, keyed by its `ScreenAreaKey` —
/// an unsplit screen by its fingerprint.
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

    /// The picked area's Show binding: the Space Bar's own value
    /// stores nothing for the area; the App Bar's nil, Per layout,
    /// clears it. A pick needs the Screen or area picker offered,
    /// whose greyed pop-up still takes one (gui.md).
    func screenShowBinding(
        _ bar: ScreenShowBar,
        on key: String
    ) -> Binding<ShelfVisibility?> {
        Binding(
            get: { self.screenShow(bar, on: key) },
            set: { value in
                guard self.offersScreenScopes else { return }
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
                case .appBar(let mode):
                    TilingSettings.appBarPath(for: mode).map {
                        self.config.settings[keyPath: $0].visibility
                    } ?? .always
                }
            },
            set: { value in
                var next = self.config.settings
                switch row {
                case .spaceBar: next.spaceBarStyle.setVisibility(value)
                case .appBar(let mode):
                    next.setAppBarVisibility(value, in: mode)
                }
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }

    /// Whether `bar` gives some screen or area a visibility of its
    /// own, which its Show row's `?` then says.
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

    /// A screen's or area's name in the Screen or area picker
    /// (#3612): as Settings ▸ Screens says it (`areaName(_:on:)`)
    /// where one connected screen carries it, else through
    /// `perScreenName(screen:key:splits:area:)`.
    func perScreenName(key: String) -> String {
        let area = ScreenAreaKey(parsing: key)
        let split =
            areaKeys(of: area.fingerprint).count > 1 || area.areaID != 0
        let found = displays.filter { $0.fingerprint == area.fingerprint }
        if found.count == 1, let display = found.first,
            !split || areaLabel(area.areaID, on: display) != nil
        {
            return areaName(split ? area.areaID : nil, on: display)
        }
        // Twins share their fingerprint's split, so either's words.
        let label =
            split
            ? found.first.flatMap { areaLabel(area.areaID, on: $0) } : nil
        return Self.perScreenName(
            screen: screenWords { $0.fingerprint == area.fingerprint }
                ?? Display.fingerprintParts(area.fingerprint).name,
            key: key,
            splits: config.settings.displayAreas,
            area: label
        )
    }

    /// A screen's or area's name where no one connected screen words
    /// it, and its diff row's: `screen`, and on a split screen
    /// `area`, else the area's stored name, else its position in the
    /// stored split (`ScreenSplit.positions`), else its number in
    /// reading order.
    static func perScreenName(
        screen: String,
        key: String,
        splits: [String: ScreenSplit],
        area label: String? = nil
    ) -> String {
        let area = ScreenAreaKey(parsing: key)
        let keys = ScreenSplit.areaKeys(of: area.fingerprint, in: splits)
        guard keys.count > 1 || area.areaID != 0 else { return screen }
        let split = splits[area.fingerprint]
        let stored = split?.areas.first { $0.id == area.areaID }?.name
        let position = split?.positions[area.areaID].map {
            ScreenAreaWords.position($0)
        }
        let place = keys.firstIndex(of: key) ?? area.areaID
        return ScreenAreaWords.composed(
            screen: screen,
            area: label ?? stored ?? position
                ?? ScreenAreaWords.position(.numbered(place + 1))
        )
    }

    /// The App Bar's "no value of its own" choice.
    static var perLayout: String {
        L("kiwishelf.show.screen.app_bar.per_layout", "Per layout")
    }
}
