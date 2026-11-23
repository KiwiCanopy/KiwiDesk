import Foundation

/// The copy one split owes (#3517): every per-area bar value of the
/// area split — its edges and its Show — given to the area the
/// split mints, so a split moves no bar. A Screen pin is no bar
/// value: a pinned Space stays on the half that keeps the id.
public struct ScreenAreaCopy: Equatable, Sendable {
    public let parent: ScreenAreaKey
    public let minted: ScreenAreaKey
}

extension GuiConfig {
    /// Splits area `id` of `split`, the screen `fingerprint`'s, along
    /// `axis` in this config, its leading half keeping the id, and
    /// copies the parent's bar values to the minted area through
    /// `apply` — the one door a split takes. Nil, changing nothing,
    /// where a half would fall under `floor`.
    @discardableResult
    public mutating func splitArea(
        _ id: Int,
        _ axis: ScreenAreaCut.Axis,
        floor: Int,
        of split: ScreenSplit,
        on fingerprint: String
    ) -> ScreenAreaCopy? {
        guard let next = split.splitting(id, axis, floor: floor) else {
            return nil
        }
        settings.displayAreas[fingerprint] = next
        let copy = ScreenAreaCopy(
            parent: ScreenAreaKey(fingerprint: fingerprint, areaID: id),
            minted: ScreenAreaKey(
                fingerprint: fingerprint,
                areaID: split.nextID
            )
        )
        apply(copy)
        return copy
    }

    /// Gives the minted area each per-area bar value the parent
    /// holds: in the settings and the shared look
    /// (`ScreenAreaSplitCopyParityTests` finds them by reflection).
    public mutating func apply(_ copy: ScreenAreaCopy) {
        settings.apply(copy)
        look?.apply(copy)
    }
}

extension LookBody {
    /// The shared look's half: a per-screen styling value is a JSON
    /// object keyed by screen, the parent's entry copied as the
    /// settings' own is.
    public mutating func apply(_ copy: ScreenAreaCopy) {
        let parent = copy.parent.description
        let minted = copy.minted.description
        for (path, value) in style {
            guard case .object(var entries) = value,
                let copied = entries[parent]
            else { continue }
            entries[minted] = copied
            style[path] = .object(entries)
        }
    }
}

extension TilingSettings {
    /// The per-area maps' half of a split's copy: both bars' and the
    /// pocket's edges, and both bars' Show.
    public mutating func apply(_ copy: ScreenAreaCopy) {
        let parent = copy.parent.description
        let minted = copy.minted.description
        spaceBarStyle.copyScreen(parent, to: minted)
        appBarStyle.copyScreen(parent, to: minted)
        kiwishelf.pocketEdges.copyScreen(parent, to: minted)
        Self.copy(parent, to: minted, in: &spaceBarStyle.visibilityOverride)
        Self.copy(parent, to: minted, in: &appBarStyle.visibilityOverride)
    }

    private static func copy(
        _ parent: String,
        to minted: String,
        in map: inout [String: ShelfVisibility]
    ) {
        if let value = map[parent] { map[minted] = value }
    }
}
