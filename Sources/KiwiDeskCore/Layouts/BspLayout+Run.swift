import CoreGraphics

/// BSP's overflow (#2542): where a split cannot hold two windows
/// at `min_window_size`, the trailing chain of same-direction
/// splits becomes one `RunZone` scrolling along the last split's
/// direction, the line known to hold two windows at the floor.
/// Windows split off in the other direction stay put.
extension BspLayout {
    /// The zones BSP scrolls: the trailing chain while a split
    /// overflows, none while every window has its slot.
    public static func zones(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [RunZone]? {
        plan(windows, in: context).zone.map { [$0] } ?? []
    }

    /// The fixed slots and the scrolled chain, if any — the one
    /// reading the render and the run share.
    struct Plan {
        var fixed: [WindowID: CGRect]
        var zone: RunZone?
    }

    static func plan(
        _ windows: [WindowID],
        in context: LayoutContext
    ) -> Plan {
        var fixed: [WindowID: CGRect] = [:]
        // Each depth's region, and the direction of each split made.
        var regions: [CGRect] = []
        var splits: [Bool] = []
        var region = context.usable
        for (depth, window) in windows.enumerated() {
            regions.append(region)
            guard depth < windows.count - 1 else {
                fixed[window] = region
                break
            }
            let across = sideBySide(region, depth: depth, context)
            guard
                let parts = divide(region, sideBySide: across, context)
            else {
                return chain(
                    windows,
                    fixed: fixed,
                    regions: regions,
                    splits: splits,
                    failing: across,
                    context
                )
            }
            splits.append(across)
            fixed[window] = parts.first
            region = parts.rest
        }
        return Plan(fixed: fixed, zone: nil)
    }

    /// The run over the trailing chain once the split at
    /// `splits.count` failed: along the last split made — the
    /// failing one's direction where none was — and as thick
    /// across as its widest member's floor, hidden ones included,
    /// taken from the split before the chain (owner, 2026-10-25).
    private static func chain(
        _ windows: [WindowID],
        fixed: [WindowID: CGRect],
        regions: [CGRect],
        splits: [Bool],
        failing: Bool,
        _ context: LayoutContext
    ) -> Plan {
        let direction = splits.last ?? failing
        var start = splits.count
        while start > 0, splits[start - 1] == direction { start -= 1 }
        let members = Array(windows[start...])
        let vertical = !direction
        var fixed = fixed
        for member in members { fixed[member] = nil }
        var region = regions[start]
        if start > 0 {
            let thickness =
                members.map {
                    context.runFloor(of: $0, horizontal: vertical)
                }.max() ?? 0
            if let parts = divide(
                regions[start - 1],
                sideBySide: splits[start - 1],
                restFloor: thickness,
                context
            ) {
                fixed[windows[start - 1]] = parts.first
                region = parts.rest
            }
        }
        return Plan(
            fixed: fixed,
            zone: RunZone(
                members: members,
                region: region,
                vertical: vertical
            )
        )
    }
}
