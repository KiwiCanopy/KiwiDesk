import CoreGraphics

/// Master/Stack layout over the flat array.
///
/// The first `masterCount` windows form the master zone (left),
/// everything after is the stack zone (right column). The zone
/// boundary is just an index — no containers (see 03_Layout).
public struct StackLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let usable = context.usable
        guard !windows.isEmpty else { return [:] }
        let masterCount = max(1, context.stack.masterCount)

        guard windows.count > masterCount else {
            // Master only: full width.
            return column(
                windows[...],
                in: usable,
                context: context
            )
        }

        let gap = context.gaps.inner.horizontal
        let ratio = CGFloat(context.stack.masterRatio)
        let masterWidth = (usable.width - gap) * ratio
        let stackWidth = usable.width - gap - masterWidth
        if min(masterWidth, stackWidth) < context.minWindowSize {
            return OverlapStack.frames(
                for: windows,
                in: usable,
                minSize: context.minWindowSize
            )
        }

        let masterRegion = CGRect(
            x: usable.minX,
            y: usable.minY,
            width: masterWidth,
            height: usable.height
        )
        let stackRegion = CGRect(
            x: usable.minX + masterWidth + gap,
            y: usable.minY,
            width: stackWidth,
            height: usable.height
        )

        var result = column(
            windows[..<masterCount],
            in: masterRegion,
            context: context
        )
        result.merge(
            column(
                windows[masterCount...],
                in: stackRegion,
                context: context
            )
        ) { _, new in new }
        return result
    }

    /// Distributes windows vertically and evenly in a region.
    /// When they stop fitting, as many windows as possible
    /// stay fully tiled and only the overflow collapses into
    /// a title-bar cascade at the bottom.
    private func column(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        let count = CGFloat(windows.count)
        guard count > 0 else { return [:] }
        let gap = context.gaps.inner.vertical
        let height = (region.height - gap * (count - 1)) / count
        if height < context.minWindowSize {
            return overflowColumn(
                windows,
                in: region,
                context: context
            )
        }
        var result: [WindowID: CGRect] = [:]
        for (offset, window) in windows.enumerated() {
            let y =
                region.minY
                + CGFloat(offset) * (height + gap)
            result[window] = CGRect(
                x: region.minX,
                y: y,
                width: region.width,
                height: height
            )
        }
        return result
    }

    /// Column overflow: the first `tiled` windows keep at
    /// least `minWindowSize`, the rest cascade at the bottom
    /// with a fixed title-bar offset — the block's last
    /// window fully visible, the buried ones showing their
    /// title bars above it. Nothing extends past the region.
    private func overflowColumn(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        let minSize = context.minWindowSize
        let gap = context.gaps.inner.vertical
        let offset = OverlapStack.offset
        let ids = Array(windows)
        for tiled in stride(
            from: ids.count - 1,
            through: 1,
            by: -1
        ) {
            let buried = CGFloat(ids.count - tiled - 1)
            let cascadeHeight = minSize + offset * buried
            let tileHeight =
                (region.height - cascadeHeight
                    - gap * CGFloat(tiled))
                / CGFloat(tiled)
            guard tileHeight >= minSize else { continue }
            var result: [WindowID: CGRect] = [:]
            var y = region.minY
            for id in ids[..<tiled] {
                result[id] = CGRect(
                    x: region.minX,
                    y: y,
                    width: region.width,
                    height: tileHeight
                )
                y += tileHeight + gap
            }
            for (index, id) in ids[tiled...].enumerated() {
                result[id] = CGRect(
                    x: region.minX,
                    y: y + CGFloat(index) * offset,
                    width: region.width,
                    height: minSize
                )
            }
            return result
        }
        // Not even one full window fits above the cascade:
        // the whole region cascades (emergency fallback).
        return OverlapStack.frames(
            for: windows,
            in: region,
            minSize: minSize
        )
    }
}

// MARK: - Stack zone array operations (see 03_Layout_Engine)

extension Space {
    /// Moves a stack-zone window into the master zone by
    /// swapping it with the last master window.
    public mutating func promote(
        _ window: WindowID,
        masterCount: Int
    ) {
        let boundary = max(1, masterCount)
        guard let index = windows.firstIndex(of: window),
            index >= boundary,
            boundary - 1 < windows.count
        else { return }
        windows.swapAt(index, boundary - 1)
    }

    /// Moves a master-zone window into the stack zone by
    /// swapping it with the first stack window.
    public mutating func demote(
        _ window: WindowID,
        masterCount: Int
    ) {
        let boundary = max(1, masterCount)
        guard let index = windows.firstIndex(of: window),
            index < boundary,
            boundary < windows.count
        else { return }
        windows.swapAt(index, boundary)
    }

    /// Spawn placement for new windows in stack mode.
    public mutating func insert(
        _ window: WindowID,
        placement: StackPlacement
    ) {
        guard !windows.contains(window) else { return }
        switch placement {
        case .master:
            windows.insert(window, at: 0)
        case .stack:
            windows.append(window)
        }
    }
}

/// `new_window_placement` for stack mode.
public enum StackPlacement: String, Sendable, Codable {
    case master
    case stack
}
