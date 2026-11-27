import KiwiDeskCore
import SwiftUI

/// One screen in the Screen or area picker (#1948, #3612), or one
/// area of a split screen (#3517 ruling 30).
struct ScreenEdgeRow: Identifiable, Equatable {
    /// The screen's number, `N`, or an area's `N#id` (#3647 ▸ lane
    /// 3c): the key its bar values are stored under.
    let id: String
    let name: String
    /// Whether a connected screen holds the number.
    let present: Bool
    /// The screen's half of `name`, which rows sort by.
    let screen: String
    /// The area's place in its screen's reading order; a leftover
    /// entry's sorts last.
    let place: Int
}

/// The screens and areas the Screen or area picker lists (#1948,
/// #3612), and the binding a picked area's Position writes.
extension SettingsModel {
    /// The draft as the main screen shows it (#1948): each bar on
    /// that screen's edge (`mainDisplay`). The Home cards picture
    /// and name it.
    var homeSettings: TilingSettings {
        config.settings.onScreen(
            mainDisplay.flatMap {
                core.barKey(
                    of: ScreenAreaKey(fingerprint: $0.fingerprint, areaID: 0),
                    order: screenOrder
                )
            }
        )
    }

    /// The screen numbers the picker lists: each of the draft
    /// profile's, save a twin's higher number, whose screen reads the
    /// lower one's values (#3647 ▸ lane 3c).
    var draftScreenNumbers: [Int] {
        let count = draftMonitorSets.map(\.monitors.count).max() ?? 0
        let held = screenOrder.fingerprints
        return (0..<count).filter { index in
            index >= held.count || !held[..<index].contains(held[index])
        }.map { $0 + 1 }
    }

    /// The draft profile's screen combinations: the edit target's
    /// saved sets — the stored profile, else the loaded one — else
    /// the connected screens as one.
    var draftMonitorSets: [MonitorSet] {
        let name = editingProfile ?? core.profiles.currentName
        let page = profileSummaries.first { $0.name == name }
        if let sets = page?.sets, !sets.isEmpty {
            return sets.map { MonitorSet(monitors: $0) }
        }
        return [MonitorSet(monitors: displays.map(\.fingerprint))]
    }

    /// Whether a bar has screens or areas to tell apart: none while
    /// the profile holds one unsplit screen (#2677, amending #1948)
    /// — unless that bar's screens already differ, which the
    /// picker must then reach.
    func offersScreenEdges<Bar: ScreenEdged>(
        _ bar: KeyPath<TilingSettings, Bar>,
        show: ScreenShowBar? = nil
    ) -> Bool {
        draftScreenNumbers.flatMap { areaKeys(ofNumber: $0) }
            .count > 1
            || config.settings[keyPath: bar].screensDiffer
            || show.map { !screenShowKeys($0).isEmpty } == true
    }

    /// The keys Screen `number`'s rows take: `N`, then each area's
    /// `N#id` in reading order where its stored split has areas.
    func areaKeys(ofNumber number: Int) -> [String] {
        guard let shares = config.settings.displayAreas[number: number],
            !shares.isWhole
        else { return ["\(number)"] }
        return ScreenArea.readingOrder(shares.areas).map {
            $0.id == 0 ? "\(number)" : "\(number)#\($0.id)"
        }
    }

    /// A bar's screen rows: each of the profile's screen numbers,
    /// one per area of a split one, and any number or area holding
    /// a value of its own, in `ordered`'s order.
    func screenEdgeRows<Bar: ScreenEdged>(
        _ bar: KeyPath<TilingSettings, Bar>,
        show: ScreenShowBar? = nil
    ) -> [ScreenEdgeRow] {
        var keys = Set(
            draftScreenNumbers.flatMap { areaKeys(ofNumber: $0) }
        )
        keys.formUnion(config.settings[keyPath: bar].edgeOverride.keys)
        keys.formUnion(show.map { screenShowKeys($0) } ?? [])
        return Self.ordered(
            keys.map { key in
                let slot = ScreenSlotKey(parsing: key)
                let number = slot.map { "\($0.number)" } ?? key
                return ScreenEdgeRow(
                    id: key,
                    name: perScreenName(key: key),
                    present: slot.map { screenOrder.holds($0) } ?? false,
                    screen: number,
                    place: slot.flatMap {
                        areaKeys(ofNumber: $0.number).firstIndex(of: key)
                    } ?? Int.max
                )
            }
        )
    }

    /// Connected screens first, then the rest, screens by number
    /// and a split screen's areas in reading order (#3612, #3647).
    static func ordered(_ rows: [ScreenEdgeRow]) -> [ScreenEdgeRow] {
        rows.sorted { a, b in
            if a.present != b.present { return a.present }
            switch a.screen.localizedStandardCompare(b.screen) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame:
                return a.place != b.place ? a.place < b.place : a.id < b.id
            }
        }
    }

    /// Every screen or area the Screen or area picker lists
    /// (#3612): each bar's rows, once.
    var screenScopes: [ScreenEdgeRow] {
        var rows: [String: ScreenEdgeRow] = [:]
        for row in screenEdgeRows(\.spaceBarStyle, show: .space)
            + screenEdgeRows(\.appBarStyle, show: .app)
            + screenEdgeRows(\.kiwishelf.pocketEdges)
        {
            rows[row.id] = rows[row.id] ?? row
        }
        return Self.ordered(Array(rows.values))
    }

    /// Whether the picker has screens or areas to tell apart: any
    /// bar's rows are offered (#2677).
    var offersScreenScopes: Bool {
        offersScreenEdges(\.spaceBarStyle, show: .space)
            || offersScreenEdges(\.appBarStyle, show: .app)
            || offersScreenEdges(\.kiwishelf.pocketEdges)
    }

    /// Whether `key` holds a value of its own for any bar: an edge,
    /// or a Show.
    func hasOwnSettings(_ key: String) -> Bool {
        config.settings.screenKeys.contains(key)
    }

    /// One screen's picker: the edge that screen gets; a pick of
    /// the bar's own edge stores nothing, judged over the draft's
    /// screens (`ScreenEdged.setEdge(_:on:among:)`).
    func screenEdge<Bar: ScreenEdged>(
        _ bar: WritableKeyPath<TilingSettings, Bar>,
        on screen: String
    ) -> Binding<AppBarEdge> {
        Binding(
            get: { self.config.settings[keyPath: bar].edge(on: screen) },
            set: { edge in
                var next = self.config.settings
                next[keyPath: bar].setEdge(
                    edge,
                    on: screen,
                    among: self.core.screenEdgeScope(
                        monitorSets: self.draftMonitorSets,
                        shares: self.config.settings.displayAreas,
                        order: self.screenOrder
                    )
                )
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }
}
