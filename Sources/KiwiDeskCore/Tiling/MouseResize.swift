import CoreGraphics

/// What a mouse resize of a tiled window does.
public enum MouseResizeMode: String, Sendable, Codable {
    /// Adjust the layout like the `resize` command: neighbors
    /// give or take space (default).
    case layout
    /// Animate the window back into its slot.
    case snapBack = "snap_back"
}

/// A mouse resize translated into a layout parameter change.
public enum ResizeAdjustment: Equatable, Sendable {
    /// BSP side-by-side split ratio delta (width drag, #56).
    case bspRatioH(CGFloat)
    /// BSP stacked split ratio delta (height drag, #56).
    case bspRatioV(CGFloat)
    case masterRatio(CGFloat)
    case scrollWidth(CGFloat)
}

/// Pure translation of mouse resizes into the same parameter
/// changes the `resize` command makes, so both paths share one
/// per-layout behavior. Pure so it is fully testable.
///
/// One deliberate exception (#67): a stack drag along the
/// zones' own axis snaps back while the keyboard `resize`
/// adjusts the focused window's per-window weight — wiring the
/// drag would need the dragged window's identity in this
/// deliberately windowless seam. Revisit if those drags are
/// asked for.
public enum MouseResize {
    /// Size deltas beyond this are a resize gesture; smaller
    /// ones are app-side clamping noise (character grids).
    public static let threshold: CGFloat = 10

    /// Whether a settled drag changed the window's size, as
    /// opposed to only moving it.
    public static func isResize(
        from slot: CGRect,
        to frame: CGRect
    ) -> Bool {
        abs(frame.width - slot.width) > threshold
            || abs(frame.height - slot.height) > threshold
    }

    /// Drops size changes made by dragging an OUTER edge —
    /// one with no neighbor slot on the far side. There is
    /// nobody to trade space with there: the window would
    /// snap back to its slot origin and the freed area would
    /// reappear on the OPPOSITE side, growing neighbors the
    /// user never dragged. Returns the frame with such axis
    /// changes reverted to the slot's size.
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

    /// Whether a point sits in the band around a rect's
    /// border — where resize drags start (the resize cursor
    /// zone extends a few points to both sides of the edge).
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

    /// The side of the first BSP split a slot sits on, as the
    /// direction the shared ratio must move for that slot's
    /// region to GROW: +1 first (left/top), -1 second. The
    /// midpoint rule is a heuristic (deep slots under extreme
    /// ratios can misread), so the mouse and keyboard paths
    /// (#122) share this one authority — never re-derive the
    /// comparison.
    public static func bspSide(
        slot: CGRect,
        bounds: CGRect,
        horizontal: Bool
    ) -> CGFloat {
        horizontal
            ? (slot.midX <= bounds.midX ? 1 : -1)
            : (slot.midY <= bounds.midY ? 1 : -1)
    }

    /// The layout change a resize gesture asks for, or nil
    /// when the layout has no parameter for that axis (the
    /// window snaps back).
    ///
    /// Signs follow the dragged window's perspective: growing
    /// a master grows the master zone; growing a stack window
    /// shrinks it. BSP infers the side of the first split
    /// from the slot's position; a width drag moves the
    /// side-by-side ratio, a height drag the stacked one (#56).
    public static func translate(
        mode: LayoutMode,
        isMaster: Bool,
        stackSplitHorizontal: Bool,
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
            // The ratio drag follows the split axis (#222);
            // the cross-axis drag snaps back (the #67
            // weight-drag exception above).
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
            // Both track adjustments (track weight, in-track
            // share) key off the dragged window's identity —
            // the same windowless-seam gap as the stack height
            // drag above (#67): drags snap back, keyboard
            // `resize` covers both axes. Revisit together.
            return nil
        case .monocle, .grid, .floating:
            return nil
        }
    }
}
