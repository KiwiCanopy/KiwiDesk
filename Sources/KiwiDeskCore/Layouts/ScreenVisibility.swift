import Foundation

/// A bar's visibility per area (#3517 ruling 30, #3618): the sparse
/// `space_bar.visibility_override` and each hosting layout's
/// `<layout>.app_bar.visibility_override` map, keyed by
/// Screen N — an area by `N#id`, an unsplit screen by its bare N —
/// taking the bar's own `always | auto | hidden`. An area with no
/// entry keeps that bar's stored visibility. It resolves
/// in the one per-screen step, `TilingSettings.onScreen(_:)`, so an
/// area's drawn and reserved strips read one answer (bars.md).
extension TilingSettings {
    /// Whether either bar gives some area a visibility of its own.
    public var hasScreenVisibilities: Bool {
        !spaceBarStyle.visibilityOverride.isEmpty
            || appBarHosts.contains { !$0.visibilityOverride.isEmpty }
    }

    /// Whether some screen or area resolves differently from the
    /// bars' own settings: an edge or a visibility of its own.
    public var hasScreenEntries: Bool {
        hasScreenEdges || hasScreenVisibilities
    }

    /// Every screen or area key a bar holds an edge or a visibility
    /// of its own on, A–Z: what `screenVariants` adds to the bars'
    /// own.
    public var screenKeys: [String] {
        Set(edgeScreens)
            .union(spaceBarStyle.visibilityOverride.keys)
            .union(appBarHosts.flatMap(\.visibilityOverride.keys))
            .sorted()
    }

    /// Each bar's visibility as `screen` has it, its entries dropped
    /// so resolving again changes nothing: the Space Bar's stored
    /// value replaced, and each hosting layout's App Bar by its own
    /// entry — never giving a layout an App Bar it lacks.
    mutating func resolveVisibilities(on screen: String?) {
        let space = screen.flatMap { spaceBarStyle.visibilityOverride[$0] }
        spaceBarStyle.visibilityOverride = [:]
        if let space { spaceBarStyle.visibility = space }
        for mode in LayoutMode.allCases {
            guard let path = Self.appBarPath(for: mode) else { continue }
            let app = screen.flatMap {
                self[keyPath: path].visibilityOverride[$0]
            }
            self[keyPath: path].visibilityOverride = [:]
            if let app { self[keyPath: path].visibility = app }
        }
    }

    /// Every hosting layout's per-area App Bar map, rewritten by
    /// `body`: the merge, split and forget doors' one walk.
    mutating func eachAppBarVisibilityMap(
        _ body: (inout [String: ShelfVisibility]) -> Void
    ) {
        for mode in LayoutMode.allCases {
            guard let path = Self.appBarPath(for: mode) else { continue }
            body(&self[keyPath: path].visibilityOverride)
        }
    }
}

extension SpaceBarStyle {
    /// The bar on every screen and area: a screen-less
    /// `set_visibility`, which clears their own values.
    public mutating func setVisibility(_ value: ShelfVisibility) {
        visibility = value
        visibilityOverride = [:]
    }

    /// One screen's or area's visibility (#3517); the bar's own
    /// value stores nothing for it.
    public mutating func setVisibility(
        _ value: ShelfVisibility,
        on screen: String
    ) {
        visibilityOverride[screen] = value == visibility ? nil : value
    }
}

extension LayoutAppBar {
    /// One screen's or area's visibility for this layout's App Bar
    /// (#3618); nil, which follows the layout's own, stores nothing.
    public mutating func setVisibility(
        _ value: ShelfVisibility?,
        on screen: String
    ) {
        visibilityOverride[screen] = value
    }
}

extension KeyedEncodingContainer {
    /// Leaves an empty `[String: ShelfVisibility]` out of the JSON
    /// (#3517), as the per-screen edge map is. The scope is the
    /// TYPE, module-wide: a store of that type that must encode an
    /// empty map needs a type of its own.
    mutating func encode(
        _ value: [String: ShelfVisibility],
        forKey key: Key
    ) throws {
        guard !value.isEmpty else { return }
        try encodeIfPresent(Optional(value), forKey: key)
    }
}
