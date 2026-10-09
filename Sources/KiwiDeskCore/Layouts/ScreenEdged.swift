import Foundation

/// A bar whose edge may differ per screen (#1948): the Space
/// Bar's and the App Bar's style. `edgeOverride` is the sparse
/// `space_bar.edge_override` / `app_bar.edge_override` map, keyed
/// by `Display.fingerprint` as a Monitor pin is; a screen with no
/// entry uses the bar's `edge`.
///
/// Write a bar's edge only through the `setEdge` doors below. The
/// verb's and Settings' writes keep no entry equal to the bar's
/// edge and collapse the entries wherever every screen agrees; a
/// look's leaves the entries exactly as they are.
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

    /// Whether some screen has an edge of its own — what makes the
    /// Settings Position master show no selection
    /// (`TilingSettings.uniformBarEdge`).
    public var screensDiffer: Bool { !edgeOverride.isEmpty }

    /// The bar on every screen: a screen-less `set_edge`, or a
    /// Settings pick of the bar's edge, which writes every level
    /// below it.
    public mutating func setEdge(_ edge: AppBarEdge) {
        self.edge = edge
        edgeOverride = [:]
    }

    /// One screen's edge (#1948). The bar's own edge stores
    /// nothing; once every screen of `scope` and of the entries
    /// has an edge of its own and all agree, the entries collapse
    /// into the bar's edge — a screen that follows the bar blocks
    /// it, since collapsing would move that screen.
    public mutating func setEdge(
        _ edge: AppBarEdge,
        on screen: String,
        among scope: ScreenEdgeScope
    ) {
        edgeOverride[screen] = edge == self.edge ? nil : edge
        let judged = scope.screens.union(edgeOverride.keys)
        let edges = Set(edgeOverride.values)
        guard edges.count == 1, let shared = edges.first,
            judged.allSatisfy({ edgeOverride[$0] != nil })
        else { return }
        setEdge(shared)
    }

    /// A look's write: the bar's edge, the entries left exactly as
    /// they are — a screen's own edge is the strongest, and the
    /// tour's Revert (`KiwiCore.unpainted`) restores the edge
    /// alone.
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
