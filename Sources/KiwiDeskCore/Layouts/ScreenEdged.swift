import Foundation

/// A bar whose edge may differ per screen (#1948): the Space
/// Bar's and the App Bar's style. `edgeOverride` is the sparse
/// `space_bar.edge_override` / `app_bar.edge_override` map, keyed
/// by `Display.fingerprint` as a Monitor pin is; a screen with no
/// entry uses the bar's `edge`.
///
/// Write a bar's edge only through the `setEdge` doors below. A
/// verb's or Settings' write of a screen's edge equal to the
/// bar's stores nothing for THAT screen, and collapses the entries
/// wherever every screen draws one edge; a look's leaves the
/// entries exactly as they are, so an entry it leaves equal to the
/// bar's edge stays a pin. Every judgement reads EFFECTIVE edges
/// (`edge(on:)`).
/// `BarEdgeWriteCensusTests` holds the raw writes to their named
/// exemptions.
public protocol ScreenEdged {
    var edge: AppBarEdge { get set }
    var edgeOverride: [String: AppBarEdge] { get set }
}

/// The screens a per-screen edge write judges its collapse over —
/// made only by `KiwiCore.screenEdgeScope(monitorSets:)`, which
/// adds the connected screens, so no write can judge fewer.
public struct ScreenEdgeScope: Sendable, Equatable {
    let screens: Set<String>
}

extension ScreenEdged {
    /// The edge this bar sits on on `screen` (a fingerprint): its
    /// own, else the bar's. Nil asks for the bar's own edge.
    public func edge(on screen: String?) -> AppBarEdge {
        screen.flatMap { edgeOverride[$0] } ?? edge
    }

    /// Whether some screen draws an edge other than the bar's —
    /// what makes the Settings Position master show no selection
    /// (`TilingSettings.uniformBarEdge`). A pin equal to the bar's
    /// edge draws the same edge, so it differs in nothing.
    public var screensDiffer: Bool {
        edgeOverride.contains { $0.value != edge }
    }

    /// The bar on every screen: a screen-less `set_edge`, or a
    /// Settings pick of the bar's edge, which writes every level
    /// below it.
    public mutating func setEdge(_ edge: AppBarEdge) {
        self.edge = edge
        edgeOverride = [:]
    }

    /// One screen's edge (#1948). The bar's own edge stores
    /// nothing for that screen. Once every screen of `scope` and
    /// of the entries DRAWS one edge (`edge(on:)`), the entries
    /// collapse into the bar's edge, which moves no screen; a
    /// screen drawing another edge — its own, or the bar's while
    /// the rest agree on a different one — keeps them apart.
    public mutating func setEdge(
        _ edge: AppBarEdge,
        on screen: String,
        among scope: ScreenEdgeScope
    ) {
        edgeOverride[screen] = edge == self.edge ? nil : edge
        let judged = scope.screens.union(edgeOverride.keys)
        let drawn = Set(judged.map { self.edge(on: $0) })
        guard !edgeOverride.isEmpty, drawn.count == 1,
            let shared = drawn.first
        else { return }
        setEdge(shared)
    }

    /// A look's write: the bar's edge, the entries left exactly as
    /// they are — a screen's own edge is the strongest, and the
    /// tour's Revert (`KiwiCore.unpainted`) restores the edge
    /// alone, never reaching the entries.
    public mutating func setEdgeKeepingScreens(_ edge: AppBarEdge) {
        self.edge = edge
    }
}

extension KeyedEncodingContainer {
    /// Leaves an empty `[String: AppBarEdge]` out of the JSON
    /// (#1948). The scope is the TYPE, module-wide: any encode of
    /// that type through a keyed container resolves here, the
    /// bars' synthesized encode of `edgeOverride` included — today
    /// its only one (`SettingsCodingTests` ▸
    /// `screenEdgesEncodeSparse`). A store of that type that must
    /// encode an empty map needs a type of its own.
    mutating func encode(
        _ value: [String: AppBarEdge],
        forKey key: Key
    ) throws {
        guard !value.isEmpty else { return }
        try encodeIfPresent(Optional(value), forKey: key)
    }
}
