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
    /// pins and the per-screen maps in the settings
    /// (`ScreenAreaRemapParityTests` finds them by reflection).
    public mutating func apply(_ remap: ScreenAreaRemap) {
        for (space, pin) in spacePins {
            spacePins[space] = remap.rewrite(pin)
        }
        settings.apply(remap)
    }
}

extension TilingSettings {
    /// The per-screen maps' half of a merge's rewrite: both bars'
    /// and the pocket's edges.
    public mutating func apply(_ remap: ScreenAreaRemap) {
        let old = remap.vanished.description
        let new = remap.survivor.description
        spaceBarStyle.moveScreen(old, to: new)
        appBarStyle.moveScreen(old, to: new)
        kiwishelf.pocketEdges.moveScreen(old, to: new)
    }
}
