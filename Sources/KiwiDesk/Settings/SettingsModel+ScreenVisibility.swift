import KiwiDeskCore
import SwiftUI

/// Which bar a screen's or area's Show belongs to (#3517 ruling
/// 30): the Space Bar's one map, or the App Bar's, which each
/// hosting layout holds for itself (#3618).
enum ScreenShowBar {
    case space
    case app
}

/// A bar's own Show row: the Space Bar's, or one layout's App Bar's.
enum BarShowRow {
    case spaceBar
    case appBar(LayoutMode)

    /// Whether the row is a layout's App Bar's.
    var isAppBar: Bool {
        if case .appBar = self { return true }
        return false
    }
}

/// A bar's Show for a picked screen or area (#3517 ruling 30,
/// #3612, #3618): an area's own visibility, keyed by its
/// `ScreenAreaKey` — an unsplit screen by its fingerprint.
extension SettingsModel {
    /// What `key` shows for `row`: the Space Bar's own value, else
    /// the bar's; a layout's App Bar entry, nil for Inherit, which
    /// follows that layout's own Show.
    func screenShow(_ row: BarShowRow, on key: String) -> ShelfVisibility? {
        let settings = config.settings
        switch row {
        case .spaceBar:
            return settings.spaceBarStyle.visibilityOverride[key]
                ?? settings.spaceBarStyle.visibility
        case .appBar(let mode):
            return TilingSettings.appBarPath(for: mode).flatMap {
                settings[keyPath: $0].visibilityOverride[key]
            }
        }
    }

    /// The picked area's Show binding: the Space Bar's own value
    /// stores nothing for the area; a layout's App Bar's nil,
    /// Inherit, clears that layout's entry. Reached only under a
    /// picked area (`KiwiShelfCard.activeScope`).
    func screenShowBinding(
        _ row: BarShowRow,
        on key: String
    ) -> Binding<ShelfVisibility?> {
        Binding(
            get: { self.screenShow(row, on: key) },
            set: { value in
                var next = self.config.settings
                switch row {
                case .spaceBar:
                    guard let value else { return }
                    next.spaceBarStyle.setVisibility(value, on: key)
                case .appBar(let mode):
                    guard let path = TilingSettings.appBarPath(for: mode)
                    else { return }
                    next[keyPath: path].setVisibility(value, on: key)
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

    /// The screens and areas `bar` gives a visibility of their own:
    /// the Space Bar's, or any hosting layout's App Bar's.
    func screenShowKeys(_ bar: ScreenShowBar) -> Set<String> {
        let settings = config.settings
        switch bar {
        case .space:
            return Set(settings.spaceBarStyle.visibilityOverride.keys)
        case .app:
            return Set(
                settings.appBarHosts.flatMap(\.visibilityOverride.keys)
            )
        }
    }

    /// A bar Show row's `?` while some screen or area shows that
    /// row its own way, which a pick there clears.
    func screenShowsHelp(_ row: BarShowRow) -> String? {
        let settings = config.settings
        let own: Bool
        switch row {
        case .spaceBar:
            own = !settings.spaceBarStyle.visibilityOverride.isEmpty
        case .appBar(let mode):
            own =
                settings.appBarHost(for: mode)?.appBar
                .visibilityOverride.isEmpty == false
        }
        return own ? BarsGateHelp.screenShowsDiffer : nil
    }

    /// The Show menu's choices for `row`: a layout's App Bar takes
    /// Inherit, which stores nothing, ahead of its three values.
    static func screenShowOptions(
        _ row: BarShowRow
    ) -> [(ShelfVisibility?, String)] {
        let values = AppBarOptions.visibility.map {
            (Optional($0.0), $0.1)
        }
        guard row.isAppBar else { return values }
        return [(nil, inheritShow)] + values
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

    /// A layout's App Bar choice with no value of its own: the
    /// layout's Show under All screens (#3618).
    static var inheritShow: String {
        L("kiwishelf.show.screen.app_bar.inherit", "Inherit")
    }
}
