import KiwiDeskCore
import SwiftUI

/// One screen in the Screen or area picker (#1948, #3612), or one
/// area of a split screen (#3517 ruling 30).
struct ScreenEdgeRow: Identifiable, Equatable {
    /// The screen's fingerprint (`Name:WxH`), which identical
    /// models share — so they share one row — or an area's
    /// `ScreenAreaKey`.
    let id: String
    let name: String
    /// How many of the profile's screens carry this fingerprint.
    let count: Int
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
        config.settings.onScreen(mainDisplay?.fingerprint)
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
        draftMonitorSets.contains { set in
            Set(set.monitors).reduce(0) { $0 + areaKeys(of: $1).count } > 1
        }
            || config.settings[keyPath: bar].screensDiffer
            || show.map { !screenShowKeys($0).isEmpty } == true
    }

    /// The keys a screen's rows take: its areas' on a split screen
    /// in the draft, in reading order (#3517), else its fingerprint.
    func areaKeys(of fingerprint: String) -> [String] {
        ScreenSplit.areaKeys(
            of: fingerprint,
            in: draftSplits
        )
    }

    /// A bar's screen rows: the profile's screens, one per area on a
    /// split screen, and any screen or area holding a value of its
    /// own, in `ordered`'s order.
    func screenEdgeRows<Bar: ScreenEdged>(
        _ bar: KeyPath<TilingSettings, Bar>,
        show: ScreenShowBar? = nil
    ) -> [ScreenEdgeRow] {
        let connected = Set(displays.map(\.fingerprint))
        var counts: [String: Int] = [:]
        for set in draftMonitorSets {
            for screen in Set(set.monitors) {
                let n = set.monitors.filter { $0 == screen }.count
                counts[screen] = max(counts[screen] ?? 0, n)
            }
        }
        // A screen split in the draft takes a row per area, and an
        // entry for an area it no longer has keeps a row of its own.
        var keyed: [String: Int] = [:]
        for (screen, count) in counts {
            for key in areaKeys(of: screen) { keyed[key] = count }
        }
        let shows = show.map { Array(screenShowKeys($0)) } ?? []
        for key in Array(config.settings[keyPath: bar].edgeOverride.keys)
            + shows
        {
            keyed[key] = max(keyed[key] ?? 0, 1)
        }
        return Self.ordered(
            keyed.map { key, count in
                let area = ScreenAreaKey(parsing: key)
                let fingerprint = area.fingerprint
                return ScreenEdgeRow(
                    id: key,
                    name: perScreenName(key: key),
                    count: count,
                    present: connected.contains(fingerprint),
                    screen: perScreenName(key: fingerprint),
                    place: areaKeys(of: fingerprint).firstIndex(of: key)
                        ?? Int.max
                )
            }
        )
    }

    /// Connected screens first, then the rest, screens A–Z by name
    /// and a split screen's areas in reading order (#3612).
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
                        shares: self.config.settings.displayAreas
                    )
                )
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }
}
