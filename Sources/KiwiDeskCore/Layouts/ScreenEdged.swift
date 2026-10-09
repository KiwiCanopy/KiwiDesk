import Foundation

/// A bar whose edge may differ per screen (#1948) — the Space
/// Bar's and the App Bar's style, so the two resolve and write
/// alike. `edgeOverride` is the sparse `space_bar.edge_override` /
/// `app_bar.edge_override` map, keyed by `Display.fingerprint` as
/// a Monitor pin is: a screen with no entry — new, unknown — uses
/// the bar's `edge`, so an entry equal to it is never stored.
protocol ScreenEdged {
    var edge: AppBarEdge { get set }
    var edgeOverride: [String: AppBarEdge] { get set }
}

extension ScreenEdged {
    /// The edge this bar sits on on `screen` (a fingerprint): its
    /// own, else the bar's. Nil asks for the bar's own edge.
    func edge(on screen: String?) -> AppBarEdge {
        screen.flatMap { edgeOverride[$0] } ?? edge
    }

    /// A screen-less `set_edge`: this bar's edge on every screen,
    /// so every screen's own entry goes.
    mutating func setEdge(_ edge: AppBarEdge) {
        self.edge = edge
        edgeOverride = [:]
    }

    /// `set_edge(edge, screen)`: the bar's own edge means "follow
    /// the bar" and removes the entry.
    mutating func setEdge(_ edge: AppBarEdge, on screen: String) {
        edgeOverride[screen] = edge == self.edge ? nil : edge
    }

    /// Collapses the entries into the bar's edge once each of
    /// `screens` — the connected ones — has an entry and every
    /// entry agrees, since every screen then ends up equal. Never
    /// with fewer than two screens: one screen's own edge says
    /// nothing about the screens a later setup adds.
    mutating func collapseScreenEdges(among screens: Set<String>) {
        let edges = Set(edgeOverride.values)
        guard edges.count == 1, let shared = edges.first,
            screens.count > 1,
            screens.allSatisfy({ edgeOverride[$0] != nil })
        else { return }
        setEdge(shared)
    }
}

extension KeyedEncodingContainer {
    /// Leaves a bar's per-screen edges out of the JSON while no
    /// screen has one (#1948): the bar styles' SYNTHESIZED encode
    /// resolves to this overload, the one `[String: AppBarEdge]`
    /// they store (`SettingsCodingTests` ▸
    /// `screenEdgesEncodeSparse`).
    mutating func encode(
        _ value: [String: AppBarEdge],
        forKey key: Key
    ) throws {
        guard !value.isEmpty else { return }
        try encodeIfPresent(Optional(value), forKey: key)
    }
}
