import Foundation

/// A bar whose edge may differ per screen (#1948): the Space
/// Bar's and the App Bar's style. `edgeOverride` is the sparse
/// `space_bar.edge_override` / `app_bar.edge_override` map, keyed
/// by `Display.fingerprint` as a Monitor pin is; a screen with no
/// entry uses the bar's `edge`.
///
/// Write a bar's edge only through the `setEdge` doors below, so
/// no entry ever equals the bar's edge and the entries collapse
/// wherever every screen agrees; `BarEdgeWriteCensusTests` holds
/// the raw `.edge =` writes to their named exemptions.
public protocol ScreenEdged {
    var edge: AppBarEdge { get set }
    var edgeOverride: [String: AppBarEdge] { get set }
}

extension ScreenEdged {
    /// The edge this bar sits on on `screen` (a fingerprint): its
    /// own, else the bar's. Nil asks for the bar's own edge.
    public func edge(on screen: String?) -> AppBarEdge {
        screen.flatMap { edgeOverride[$0] } ?? edge
    }

    /// Whether some screen has an edge of its own — the bar's
    /// screens differ, so a control for the bar's edge shows no
    /// selection.
    public var screensDiffer: Bool { !edgeOverride.isEmpty }

    /// The bar on every screen: a screen-less `set_edge`, or a
    /// pick of the bar's edge, which writes every level below it.
    public mutating func setEdge(_ edge: AppBarEdge) {
        self.edge = edge
        edgeOverride = [:]
    }

    /// One screen's edge, judged over `screens` — the screens
    /// `KiwiCore.screenEdgeScope` names (#1948). The bar's own
    /// edge stores nothing; once every screen of `screens` and of
    /// the entries has an edge of its own and all agree, the
    /// entries collapse into the bar's edge.
    public mutating func setEdge(
        _ edge: AppBarEdge,
        on screen: String,
        among screens: Set<String>
    ) {
        edgeOverride[screen] = edge
        settle(among: screens)
    }

    /// A look's write: the bar's edge, each screen's own kept —
    /// it is the strongest — save an entry the new edge now
    /// equals. A look knows no screen set, so it never collapses;
    /// pruning alone moves no screen.
    public mutating func setEdgeKeepingScreens(_ edge: AppBarEdge) {
        self.edge = edge
        edgeOverride = edgeOverride.filter { $0.value != edge }
    }

    private mutating func settle(among screens: Set<String>) {
        edgeOverride = edgeOverride.filter { $0.value != edge }
        let scope = screens.union(edgeOverride.keys)
        let edges = Set(edgeOverride.values)
        guard edges.count == 1, let shared = edges.first,
            scope.allSatisfy({ edgeOverride[$0] != nil })
        else { return }
        setEdge(shared)
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
