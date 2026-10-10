import KiwiDeskCore
import SwiftUI

/// One screen row in a bar's Per screen drawer (#1948).
struct ScreenEdgeRow: Identifiable, Equatable {
    /// The screen's fingerprint (`Name:WxH`), which identical
    /// models share — so they share one row.
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
    /// that screen's edge. The Home cards picture and name it. The
    /// main screen is the one at the AppKit origin.
    var homeSettings: TilingSettings {
        config.settings.onScreen(
            displays.first { $0.frame.origin == .zero }?.fingerprint
        )
    }

    /// The draft profile's screen combinations: the page's saved
    /// sets, else the connected screens as one.
    var draftMonitorSets: [MonitorSet] {
        let page = profileSummaries.first { $0.name == reachPage }
        if let sets = page?.sets, !sets.isEmpty {
            return sets.map { MonitorSet(monitors: $0) }
        }
        return [MonitorSet(monitors: displays.map(\.fingerprint))]
    }

    /// Whether the Per screen rows show: hidden, never greyed,
    /// while the profile holds one screen (#1948 ruling).
    var offersScreenEdges: Bool {
        draftMonitorSets.contains { $0.monitors.count > 1 }
    }

    /// The profile's screens, one row per fingerprint: connected
    /// ones first, then the rest, each A–Z by name.
    var screenEdgeRows: [ScreenEdgeRow] {
        let connected = Set(displays.map(\.fingerprint))
        var counts: [String: Int] = [:]
        for set in draftMonitorSets {
            for screen in Set(set.monitors) {
                let n = set.monitors.filter { $0 == screen }.count
                counts[screen] = max(counts[screen] ?? 0, n)
            }
        }
        return counts.map { screen, count in
            ScreenEdgeRow(
                id: screen,
                name: Display.fingerprintParts(screen).name,
                count: count,
                present: connected.contains(screen)
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
                        monitorSets: self.draftMonitorSets
                    )
                )
                guard next != self.config.settings else { return }
                self.config.settings = next
            }
        )
    }
}
