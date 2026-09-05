import CoreGraphics

/// Mouse resize handling strategy for tiled windows.
public enum MouseResizeMode: String, Sendable, Codable, CaseIterable {
    /// Adjust layout parameter based on drag (default).
    case layout
    /// Animate window back into layout slot.
    case snapBack = "snap_back"
}

/// Layout parameter adjustment derived from mouse resize (#56, #128).
public enum ResizeAdjustment: Equatable, Sendable {
    case bspRatioH(CGFloat)
    case bspRatioV(CGFloat)
    case masterRatio(CGFloat)
    case scrollWidth(CGFloat)
    case trackAcross(CGFloat)
    case trackAlong(CGFloat)
}

/// Translates mouse resizes into layout adjustments (#56, #122, #128).
public enum MouseResize {
    /// Minimum size delta to qualify as intentional resize gesture.
    public static let threshold: CGFloat = 10

    /// Whether frame difference exceeds resize threshold.
    public static func isResize(
        from slot: CGRect,
        to frame: CGRect
    ) -> Bool {
        abs(frame.width - slot.width) > threshold
            || abs(frame.height - slot.height) > threshold
    }

    /// Drops size changes from dragging an outer edge lacking neighbors.
    public static func keepingInnerEdgeChanges(
        slot: CGRect,
        frame: CGRect,
        neighbors: [CGRect]
    ) -> CGRect {
        var result = frame
        let movedLeft =
            abs(frame.minX - slot.minX) > threshold
        let movedRight =
            abs(frame.maxX - slot.maxX) > threshold
        if movedLeft || movedRight {
            let ok =
                (movedLeft
                    && neighbors.contains {
                        $0.midX < slot.minX
                    })
                || (movedRight
                    && neighbors.contains {
                        $0.midX > slot.maxX
                    })
            if !ok {
                result.size.width = slot.width
            }
        }
        // AX coordinates: minY is the top edge.
        let movedTop =
            abs(frame.minY - slot.minY) > threshold
        let movedBottom =
            abs(frame.maxY - slot.maxY) > threshold
        if movedTop || movedBottom {
            let ok =
                (movedTop
                    && neighbors.contains {
                        $0.midY < slot.minY
                    })
                || (movedBottom
                    && neighbors.contains {
                        $0.midY > slot.maxY
                    })
            if !ok {
                result.size.height = slot.height
            }
        }
        return result
    }

    /// Whether a point lies in the resize border band of a rect.
    public static func nearEdge(
        _ point: CGPoint,
        of rect: CGRect,
        tolerance: CGFloat = 10
    ) -> Bool {
        let outer = rect.insetBy(
            dx: -tolerance,
            dy: -tolerance
        )
        let inner = rect.insetBy(
            dx: tolerance,
            dy: tolerance
        )
        return outer.contains(point)
            && !inner.contains(point)
    }

    /// Direction (+1 / -1) to move BSP ratio to grow target slot (#122).
    public static func bspSide(
        slot: CGRect,
        bounds: CGRect,
        horizontal: Bool
    ) -> CGFloat {
        horizontal
            ? (slot.midX <= bounds.midX ? 1 : -1)
            : (slot.midY <= bounds.midY ? 1 : -1)
    }

    /// How far a slot's extent may fall short of the tiled
    /// extent and still count as spanning it: the layout's own
    /// arithmetic, so sub-point rounding is the only gap to
    /// absorb. A window that really is split off is short by an
    /// inner gap plus a min-size share, never by a point.
    private static let spanTolerance: CGFloat = 1

    /// Sorts tiled slots onto the two sides of the first split
    /// on one axis, DROPPING the windows that take no part in
    /// it (#1259): a slot spanning the whole tiled extent lies
    /// above every split of that orientation, so no ratio move
    /// can change its size. It belongs to neither side, and a
    /// side that counts it can come back naming it as the
    /// window that cannot move — which tells the user the wrong
    /// window is stuck.
    ///
    /// The extent is the UNION of the slots rather than the
    /// layout region: the tiling fills its region, so the union
    /// is the same number already inset by the outer gaps,
    /// which the region is not. `bounds` stays the region for
    /// the side comparison itself (#537).
    public static func bspSides(
        of windows: some Sequence<WindowID>,
        slots: [WindowID: CGRect],
        bounds: CGRect,
        horizontal: Bool
    ) -> (first: [WindowID], second: [WindowID]) {
        let placed = windows.compactMap { id in
            slots[id].map { (id: id, slot: $0) }
        }
        let extent = placed.reduce(CGRect.null) {
            $0.union($1.slot)
        }
        let whole = horizontal ? extent.width : extent.height
        var first: [WindowID] = []
        var second: [WindowID] = []
        for (id, slot) in placed {
            let own = horizontal ? slot.width : slot.height
            guard own < whole - spanTolerance else { continue }
            let side = bspSide(
                slot: slot,
                bounds: bounds,
                horizontal: horizontal
            )
            if side > 0 {
                first.append(id)
            } else {
                second.append(id)
            }
        }
        return (first, second)
    }

    /// Translates frame change into layout parameter adjustment
    /// (#56, #222, #925).
    public static func translate(
        mode: LayoutMode,
        isMaster: Bool,
        stackSplitHorizontal: Bool,
        // Required on purpose (#925 review): a defaulted
        // discriminator lets a new call site silently classify a
        // horizontal-track drag with the vertical mapping.
        trackAxisVertical: Bool,
        slot: CGRect,
        frame: CGRect,
        bounds: CGRect
    ) -> ResizeAdjustment? {
        let dw = frame.width - slot.width
        let dh = frame.height - slot.height
        switch mode {
        case .bsp:
            if abs(dw) >= abs(dh), abs(dw) > threshold {
                let side = bspSide(
                    slot: slot,
                    bounds: bounds,
                    horizontal: true
                )
                return .bspRatioH(side * dw / bounds.width)
            }
            if abs(dh) > threshold {
                let side = bspSide(
                    slot: slot,
                    bounds: bounds,
                    horizontal: false
                )
                return .bspRatioV(side * dh / bounds.height)
            }
            return nil
        case .stack:
            // The ratio drag follows the split axis (#222); the
            // cross-axis drag snaps back (the #67 weight-drag
            // exception).
            let change = stackSplitHorizontal ? dw : dh
            guard abs(change) > threshold else { return nil }
            let sign: CGFloat = isMaster ? 1 : -1
            let extent =
                stackSplitHorizontal
                ? bounds.width : bounds.height
            return .masterRatio(sign * change / extent)
        case .scrolling:
            guard abs(dw) > threshold else { return nil }
            return .scrollWidth(dw)
        case .track:
            if trackAxisVertical {
                if abs(dw) >= abs(dh), abs(dw) > threshold {
                    return .trackAcross(dw)
                }
                if abs(dh) > threshold {
                    return .trackAlong(dh)
                }
            } else {
                if abs(dh) >= abs(dw), abs(dh) > threshold {
                    return .trackAcross(dh)
                }
                if abs(dw) > threshold {
                    return .trackAlong(dw)
                }
            }
            return nil
        case .monocle, .grid, .floating:
            return nil
        }
    }
}
