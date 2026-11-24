import Foundation
import Testing

@testable import KiwiDeskCore

/// Every per-screen map in `TilingSettings` — a `[String: AppBarEdge]`
/// or `[String: ShelfVisibility]` anywhere in its tree, keyed by a
/// screen's or an area's key (#1948, #3376, #3517) — is pruned by the
/// one `keepScreenEdges(in:)`, so a forgotten screen setup leaves
/// none behind. The maps are discovered by reflection, so a new one
/// reds here until `keepScreenEdges` reaches it and `fill` names it.
/// Its blind spot: a per-screen map of another value type, which
/// `isScreenKeyed` names by type and a new type joins.
@Suite("Screen-keyed map census (#3517)")
struct ScreenKeyedMapCensusTests {
    private static let gone = "Gone:100x100#1"

    /// The dotted paths of every screen-keyed map under `value`.
    private func screenKeyedMaps(
        in value: Any,
        at path: String = "settings"
    ) -> [String] {
        Mirror(reflecting: value).children.flatMap {
            child -> [String] in
            guard let label = child.label else { return [] }
            let here = "\(path).\(label)"
            if isScreenKeyed(child.value) { return [here] }
            if type(of: child.value) == [String: ScreenSplit].self {
                return []
            }
            return screenKeyedMaps(in: child.value, at: here)
        }
    }

    /// By the value's own type: an `is` cast passes an EMPTY map of
    /// any value type, which reads every Space-keyed map as one.
    private func isScreenKeyed(_ value: Any) -> Bool {
        let kind = type(of: value)
        return kind == [String: AppBarEdge].self
            || kind == [String: ShelfVisibility].self
    }

    /// An area of a screen in scope, whose entries every map keeps.
    private static let kept = "Wide:3440x1440#1"

    /// Settings with every screen-keyed map holding `keys`.
    private func fill(_ keys: [String] = [gone]) -> TilingSettings {
        var settings = TilingSettings()
        let edges = Dictionary(
            uniqueKeysWithValues: keys.map {
                ($0, AppBarEdge.left)
            }
        )
        let shows = Dictionary(
            uniqueKeysWithValues: keys.map {
                ($0, ShelfVisibility.hidden)
            }
        )
        settings.spaceBarStyle.edgeOverride = edges
        settings.appBarStyle.edgeOverride = edges
        settings.kiwishelf.pocketEdgeOverride = edges
        settings.spaceBarStyle.visibilityOverride = shows
        settings.monocle.appBar.visibilityOverride = shows
        settings.scrolling.appBar.visibilityOverride = shows
        return settings
    }

    @Test("an area's entry survives while its screen is in scope")
    func areaEntriesSurvive() {
        var kept = fill([Self.gone, Self.kept])
        let maps = screenKeyedMaps(in: kept)
        kept.keepScreenEdges(
            in: ScreenEdgeScope(screens: ["Wide:3440x1440"])
        )
        for path in maps {
            #expect(
                lookup(path, in: kept) == [Self.kept],
                Comment(rawValue: path)
            )
        }
    }

    @Test("every screen-keyed map is pruned by keepScreenEdges")
    func everyMapIsPruned() {
        let filled = fill()
        let maps = screenKeyedMaps(in: filled)
        #expect(maps.count >= 5)
        // The fixture fills every map the census finds.
        let nonEmpty = maps.filter { path in
            !(lookup(path, in: filled)?.isEmpty ?? true)
        }
        #expect(Set(nonEmpty) == Set(maps), "unfilled: \(maps)")
        var kept = filled
        kept.keepScreenEdges(in: KiwiCoreTestScope.empty)
        for path in maps {
            #expect(
                lookup(path, in: kept)?.isEmpty == true,
                Comment(rawValue: "\(path) keeps a gone screen")
            )
        }
    }

    /// The keys of the screen-keyed map at `path`.
    private func lookup(
        _ path: String,
        in settings: TilingSettings
    ) -> Set<String>? {
        var value: Any = settings
        for part in path.split(separator: ".").dropFirst() {
            guard
                let next = Mirror(reflecting: value).children.first(
                    where: { $0.label == String(part) }
                )?.value
            else { return nil }
            value = next
        }
        if let edges = value as? [String: AppBarEdge] {
            return Set(edges.keys)
        }
        if let shows = value as? [String: ShelfVisibility] {
            return Set(shows.keys)
        }
        return nil
    }
}

private enum KiwiCoreTestScope {
    static var empty: ScreenEdgeScope { ScreenEdgeScope(screens: []) }
}
