import Foundation

/// A bar's visibility per area (#3517 ruling 30): the sparse
/// `space_bar.visibility_override` / `app_bar.visibility_override`
/// map, keyed by `ScreenAreaKey` — an unsplit screen by its bare
/// fingerprint — taking the bar's own `always | auto | hidden`. An
/// area with no entry keeps the bar's stored visibility. It resolves
/// in the one per-screen step, `TilingSettings.onScreen(_:)`, so an
/// area's drawn and reserved strips read one answer (bars.md).
extension TilingSettings {
    /// Whether either bar gives some area a visibility of its own.
    public var hasScreenVisibilities: Bool {
        !spaceBarStyle.visibilityOverride.isEmpty
            || !appBarStyle.visibilityOverride.isEmpty
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
            .union(appBarStyle.visibilityOverride.keys)
            .sorted()
    }

    /// Each bar's visibility as `screen` has it, its entries dropped
    /// so resolving again changes nothing: the Space Bar's stored
    /// value replaced, and the App Bar's in every layout that carries
    /// one — never giving a layout an App Bar it lacks.
    mutating func resolveVisibilities(on screen: String?) {
        let space = screen.flatMap { spaceBarStyle.visibilityOverride[$0] }
        let app = screen.flatMap { appBarStyle.visibilityOverride[$0] }
        spaceBarStyle.visibilityOverride = [:]
        appBarStyle.visibilityOverride = [:]
        if let space { spaceBarStyle.visibility = space }
        guard let app else { return }
        for mode in LayoutMode.allCases {
            guard let path = Self.appBarPath(for: mode) else { continue }
            self[keyPath: path].visibility = app
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

extension AppBarStyle {
    /// One screen's or area's App Bar visibility (#3517); nil, which
    /// follows each layout's own, stores nothing.
    public mutating func setVisibility(
        _ value: ShelfVisibility?,
        on screen: String
    ) {
        visibilityOverride[screen] = value
    }
}

extension TilingSettings {
    /// A layout's own App Bar visibility — its Settings row or
    /// `<layout>.set_app_bar_visibility` — which clears every area's
    /// App Bar value (#3517 ruling 32), as the Space Bar's
    /// `setVisibility(_:)` clears its own.
    public mutating func setLayoutAppBarVisibility(
        _ value: ShelfVisibility,
        in layout: WritableKeyPath<TilingSettings, LayoutAppBar>
    ) {
        self[keyPath: layout].visibility = value
        appBarStyle.visibilityOverride = [:]
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
