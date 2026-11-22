import KiwiDeskCore
import SwiftUI

/// One screen row in a bar's Per screen drawer (#1948), or one
/// area's on a split screen (#3517 ruling 30).
struct ScreenEdgeRow: Identifiable, Equatable {
    /// The screen's fingerprint (`Name:WxH`), which identical
    /// models share — so they share one row — or an area's
    /// `ScreenAreaKey`.
    let id: String
    let name: String
    /// How many of the profile's screens carry this fingerprint.
    let count: Int
    let present: Bool
}

/// The Per screen rows under each bar's edge (#1948): which
/// screens get a row, and the binding a screen's picker writes.
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

    /// Whether a bar's Per screen rows can show: its rows grey
    /// while the profile holds one screen (#2677, amending
    /// #1948) — unless that bar's screens already differ, which
    /// the rows must then show.
    func offersScreenEdges<Bar: ScreenEdged>(
        _ bar: KeyPath<TilingSettings, Bar>,
        show: ScreenShowBar? = nil
    ) -> Bool {
        draftMonitorSets.contains { set in
            Set(set.monitors).reduce(0) { $0 + areaKeys(of: $1).count } > 1
        }
            || config.settings[keyPath: bar].screensDiffer
            || show.map(hasScreenShows) == true
    }

    /// The keys a screen's rows take: its areas' on a split screen
    /// in the draft, in reading order (#3517), else its fingerprint.
    func areaKeys(of fingerprint: String) -> [String] {
        ScreenSplit.areaKeys(of: fingerprint, in: config.settings.displayAreas)
    }

    /// A bar's screen rows, one per fingerprint: the profile's
    /// screens and any screen holding an edge of its own,
    /// connected ones first, then the rest, each A–Z by name.
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
        var split: Set<String> = []
        for (screen, count) in counts {
            let keys = areaKeys(of: screen)
            if keys.count > 1 { split.insert(screen) }
            for key in keys { keyed[key] = count }
        }
        let shows: [String] =
            switch show {
            case .space?:
                Array(config.settings.spaceBarStyle.visibilityOverride.keys)
            case .app?:
                Array(config.settings.appBarStyle.visibilityOverride.keys)
            case nil: []
            }
        for key in Array(config.settings[keyPath: bar].edgeOverride.keys)
            + shows
        {
            keyed[key] = max(keyed[key] ?? 0, 1)
        }
        return keyed.map { key, count in
            let area = ScreenAreaKey(parsing: key)
            return ScreenEdgeRow(
                id: key,
                name: Self.perScreenName(
                    screen: Display.fingerprintParts(area.fingerprint).name,
                    areaID: area.areaID,
                    split: split.contains(area.fingerprint)
                        || area.areaID != 0
                ),
                count: count,
                present: connected.contains(area.fingerprint)
            )
        }
        .sorted { a, b in
            if a.present != b.present { return a.present }
            switch a.name.localizedStandardCompare(b.name) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return a.id < b.id
            }
        }
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
                        splits: self.config.settings.displayAreas
                    )
                )
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }
}
