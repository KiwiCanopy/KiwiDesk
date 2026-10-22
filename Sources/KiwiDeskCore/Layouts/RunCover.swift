import CoreGraphics

/// Which windows a Space's scrolled runs hide, and the shown
/// window each waits behind (#2235) — what a z-order restore
/// must stack: every hidden window under its edge window.
public struct RunCover: Sendable, Equatable {
    public let space: SpaceID
    /// Hidden window → the shown window whose slot it shares.
    public let behind: [WindowID: WindowID]
    /// The first shown window of each run that hides any ahead
    /// of it — what `Space.runHeads` stores.
    public let heads: Set<WindowID>

    public init(
        space: SpaceID,
        behind: [WindowID: WindowID],
        heads: Set<WindowID>
    ) {
        self.space = space
        self.behind = behind
        self.heads = heads
    }

    /// The cover `mode` draws over `tiled`, or nil for a layout
    /// that scrolls no zone.
    public static func of(
        space: SpaceID,
        mode: LayoutMode,
        tiled: [WindowID],
        in context: LayoutContext
    ) -> RunCover? {
        let zones: [RunZone]?
        switch mode {
        case .stack: zones = StackLayout.zones(for: tiled, in: context)
        case .track: zones = TrackLayout.zones(for: tiled, in: context)
        default: return nil
        }
        var behind: [WindowID: WindowID] = [:]
        var heads: Set<WindowID> = []
        for zone in zones ?? [] {
            guard let run = zone.run(in: context), run.hides else {
                continue
            }
            let members = zone.members
            let first = run.visible.lowerBound
            let last = run.visible.upperBound - 1
            if first > 0 { heads.insert(members[first]) }
            for index in 0..<first { behind[members[index]] = members[first] }
            for index in (last + 1)..<members.count {
                behind[members[index]] = members[last]
            }
        }
        return RunCover(space: space, behind: behind, heads: heads)
    }

    /// The zone holding `window` and the run it draws, nil where
    /// `window` is in no scrolled zone.
    public static func zone(
        of window: WindowID,
        mode: LayoutMode,
        tiled: [WindowID],
        in context: LayoutContext
    ) -> RunZone? {
        let zones: [RunZone]?
        switch mode {
        case .stack: zones = StackLayout.zones(for: tiled, in: context)
        case .track: zones = TrackLayout.zones(for: tiled, in: context)
        default: return nil
        }
        return zones?.first { $0.members.contains(window) }
    }

    /// The raise order that stacks each hidden window under the
    /// window it waits behind: the hidden first, in array order,
    /// then their edge windows.
    public func raiseOrder(in tiled: [WindowID]) -> [WindowID] {
        let edges = Set(behind.values)
        return tiled.filter { behind[$0] != nil }
            + tiled.filter { edges.contains($0) }
    }
}
