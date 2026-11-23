import Foundation

/// The key rewrite one merge owes (#3517 ruling 22): every stored
/// reference to the area that vanished moves to the area that
/// absorbed it, which is physically the same place.
public struct ScreenAreaRemap: Equatable, Sendable {
    public let vanished: ScreenAreaKey
    public let survivor: ScreenAreaKey

    /// `key` as it reads after the merge.
    public func rewrite(_ key: String) -> String {
        ScreenAreaKey(parsing: key) == vanished
            ? survivor.description : key
    }
}

extension GuiConfig {
    /// Merges areas `a` and `b` of the screen `fingerprint` in this
    /// config and rewrites every key-bearing field through `apply`
    /// — the one door a merge takes. Nil, changing nothing, where
    /// the screen has no such split or the two share no full edge.
    @discardableResult
    public mutating func mergeAreas(
        _ a: Int,
        _ b: Int,
        on fingerprint: String
    ) -> ScreenAreaRemap? {
        guard
            let merged = settings.displayAreas[fingerprint]?
                .merging(a, b)
        else { return nil }
        settings.displayAreas[fingerprint] = merged.split
        let remap = ScreenAreaRemap(
            vanished: ScreenAreaKey(
                fingerprint: fingerprint,
                areaID: merged.vanished
            ),
            survivor: ScreenAreaKey(
                fingerprint: fingerprint,
                areaID: merged.survivor
            )
        )
        apply(remap)
        return remap
    }

    /// Rewrites every field that stores an area key: the Screen
    /// pins, the areas' Desktop memory and the per-screen maps in
    /// the settings (`ScreenAreaRemapParityTests` finds them by
    /// reflection).
    public mutating func apply(_ remap: ScreenAreaRemap) {
        for (space, pin) in spacePins {
            spacePins[space] = remap.rewrite(pin)
        }
        let old = remap.vanished.description
        let new = remap.survivor.description
        for (desktop, var shown) in desktopAreaSpaces {
            guard let moved = shown.removeValue(forKey: old) else {
                continue
            }
            if shown[new] == nil { shown[new] = moved }
            desktopAreaSpaces[desktop] = shown
        }
        settings.apply(remap)
        look?.apply(remap)
    }
}

extension LookBody {
    /// The shared look's half: a per-screen styling value (the bars'
    /// and the pocket's `edge_override`) is a JSON object keyed by
    /// screen, its vanished entry moved as `ScreenEdged.moveScreen`
    /// moves the settings' own.
    public mutating func apply(_ remap: ScreenAreaRemap) {
        let old = remap.vanished.description
        let new = remap.survivor.description
        for (path, value) in style {
            guard case .object(var entries) = value,
                let moved = entries.removeValue(forKey: old)
            else { continue }
            if entries[new] == nil { entries[new] = moved }
            style[path] = .object(entries)
        }
    }
}

extension TilingSettings {
    /// The per-screen maps' half of a merge's rewrite: both bars'
    /// and the pocket's edges, and both bars' Show.
    public mutating func apply(_ remap: ScreenAreaRemap) {
        let old = remap.vanished.description
        let new = remap.survivor.description
        spaceBarStyle.moveScreen(old, to: new)
        appBarStyle.moveScreen(old, to: new)
        kiwishelf.pocketEdges.moveScreen(old, to: new)
        Self.move(old, to: new, in: &spaceBarStyle.visibilityOverride)
        Self.move(old, to: new, in: &appBarStyle.visibilityOverride)
    }

    /// A merged-away area's Show moved to the area that absorbed it
    /// where that area has none of its own, as `moveScreen` moves an
    /// edge (ruling 22).
    private static func move(
        _ old: String,
        to new: String,
        in map: inout [String: ShelfVisibility]
    ) {
        guard let moved = map.removeValue(forKey: old) else { return }
        if map[new] == nil { map[new] = moved }
    }
}
