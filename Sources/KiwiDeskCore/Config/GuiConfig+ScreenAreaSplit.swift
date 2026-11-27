import Foundation

/// The copy one split owes (#3517): every per-area bar value of the
/// area split — its edges and its Show — given to the area the
/// split mints, so a split moves no bar. A Screen pin is no bar
/// value: a pinned Space stays on the half that keeps the id. Keyed
/// by screen number (#3647 ▸ lane 3).
public struct ScreenAreaCopy: Equatable, Sendable {
    public let parent: ScreenSlotKey
    public let minted: ScreenSlotKey
}

extension GuiConfig {
    /// Splits area `id` of `split`, the screen `fingerprint`'s, along
    /// `axis` in this config, its leading half keeping the id, and
    /// copies the parent's bar values to the minted area through
    /// `apply` — the one door a split takes. Nil, changing nothing,
    /// where a half would fall under `floor` or the screen holds no
    /// number.
    @discardableResult
    public mutating func splitArea(
        _ id: Int,
        _ axis: ScreenAreaCut.Axis,
        floor: Int,
        of split: ScreenSplit,
        on fingerprint: String,
        order: ScreenOrder
    ) -> ScreenAreaCopy? {
        guard let number = order.number(of: fingerprint),
            let next = split.splitting(id, axis, floor: floor),
            let parent = ScreenSlotKey(number: number, areaID: id),
            let minted = ScreenSlotKey(number: number, areaID: split.nextID)
        else { return nil }
        settings.displayAreas.store(next, on: fingerprint, order: order)
        let copy = ScreenAreaCopy(parent: parent, minted: minted)
        apply(copy)
        return copy
    }

    /// Gives the minted area each per-area bar value the parent
    /// holds (`ScreenAreaSplitCopyParityTests` finds them by
    /// reflection).
    public mutating func apply(_ copy: ScreenAreaCopy) {
        settings.apply(copy)
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
        eachAppBarVisibilityMap { Self.copy(parent, to: minted, in: &$0) }
    }

    private static func copy(
        _ parent: String,
        to minted: String,
        in map: inout [String: ShelfVisibility]
    ) {
        if let value = map[parent] { map[minted] = value }
    }
}
