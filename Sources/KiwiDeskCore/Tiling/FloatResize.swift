import CoreGraphics

/// Symmetric keyboard resize math for floating windows with
/// boundary-edge pinning (#1091, owner ruling 2026-08-29;
/// `FloatSymmetricResizeTests`). One accepted residue:
/// reversibility does not hold across the step that FIRST brings
/// a window into contact with a boundary (bounded by half a step,
/// confined to that transition). Do NOT answer it by remembering
/// which way the last grow went — a stored direction needs
/// invalidating on every move, mode and display change, and buys
/// back less than it costs.
public enum FloatResize {
    /// Tolerance for detecting contact with a boundary edge (1 pt).
    public static let boundaryTolerance: CGFloat = 1

    /// Floor for a frame shrink: `min_window_size`, never below
    /// 1 pt (AppKit rejects zero frames). `resized` caps this at
    /// the CURRENT size, so the floor never LIFTS a frame.
    public static func shrinkFloor(
        minSize: CGFloat
    ) -> CGFloat {
        max(minSize, 1)
    }

    /// Why a grow operation was blocked or truncated (#933, 2026-08-29).
    public enum Refusal: Equatable {
        /// Both edges against the boundary — nothing moved.
        case blocked
        /// Moved, but by less than the delta asked for.
        case truncated
    }

    /// Resize outcome and refusal status.
    public struct Outcome: Equatable {
        public let frame: CGRect
        public let refusal: Refusal?
    }

    /// Resizes floating `frame` along axis by `delta`, splitting symmetrically
    /// with edge pinning against `bounds` (#1091).
    public static func resized(
        _ frame: CGRect,
        horizontal: Bool,
        delta: CGFloat,
        minSize: CGFloat,
        bounds: CGRect?
    ) -> Outcome {
        let origin = horizontal ? frame.minX : frame.minY
        let extent = horizontal ? frame.width : frame.height
        let low = bounds.map { horizontal ? $0.minX : $0.minY }
        let high = bounds.map { horizontal ? $0.maxX : $0.maxY }
        let span =
            delta >= 0
            ? grown(
                origin: origin,
                extent: extent,
                delta: delta,
                low: low,
                high: high
            )
            : shrunk(
                origin: origin,
                extent: extent,
                magnitude: -delta,
                minSize: minSize,
                low: low,
                high: high
            )
        var result = frame
        if horizontal {
            result.origin.x = span.origin
            result.size.width = span.extent
        } else {
            result.origin.y = span.origin
            result.size.height = span.extent
        }
        return Outcome(frame: result, refusal: span.refusal)
    }

    /// One axis of a resize: where the near edge lands and how
    /// long the window ends up.
    private struct Span {
        var origin: CGFloat
        var extent: CGFloat
        var refusal: Refusal?
    }

    /// Half the delta to each side, each capped by the room it
    /// actually has, with whatever a capped side could not take
    /// spilling to the other. That spill IS the pinned-edge rule
    /// — an edge with no room takes nothing and the whole delta
    /// lands on the far side — so the two are one expression
    /// rather than a special case beside a general one.
    private static func grown(
        origin: CGFloat,
        extent: CGFloat,
        delta: CGFloat,
        low: CGFloat?,
        high: CGFloat?
    ) -> Span {
        let roomLow = low.map { max(0, origin - $0) } ?? .infinity
        let roomHigh =
            high.map { max(0, $0 - (origin + extent)) }
            ?? .infinity
        guard roomLow + roomHigh > boundaryTolerance else {
            return Span(
                origin: origin,
                extent: extent,
                refusal: .blocked
            )
        }
        // Deliberately NOT pre-capped at `roomLow + roomHigh`
        // (guard-prover, 2026-08-29). Each side is capped by its
        // own room below and the spill is capped by what is
        // left, so a total cap here is arithmetically redundant
        // — and a line no mutation can red reads as load-bearing
        // while guarding nothing.
        var takeLow = min(delta / 2, roomLow)
        var takeHigh = min(delta / 2, roomHigh)
        let spill = delta - takeLow - takeHigh
        if spill > 0 {
            let toLow = min(spill, roomLow - takeLow)
            takeLow += toLow
            takeHigh += min(spill - toLow, roomHigh - takeHigh)
        }
        let taken = takeLow + takeHigh
        return Span(
            origin: origin - takeLow,
            extent: extent + taken,
            // Short of the ask, so the boundary took part of the
            // request even though the window did move.
            refusal: delta - taken > boundaryTolerance
                ? .truncated
                : nil
        )
    }

    /// The mirror: contract by half from each side, unless one
    /// edge is pinned — then that edge holds and the whole
    /// contraction comes off the other. Both pinned contracts
    /// symmetrically rather than refusing: a shrink always has
    /// somewhere to go, and refusing it would strand a
    /// wall-to-wall window at a size it could never leave.
    private static func shrunk(
        origin: CGFloat,
        extent: CGFloat,
        magnitude: CGFloat,
        minSize: CGFloat,
        low: CGFloat?,
        high: CGFloat?
    ) -> Span {
        let floor = min(shrinkFloor(minSize: minSize), extent)
        let shed = extent - max(extent - magnitude, floor)
        let pinnedLow =
            low.map { origin - $0 <= boundaryTolerance } ?? false
        let pinnedHigh =
            high.map {
                $0 - (origin + extent) <= boundaryTolerance
            } ?? false
        let moveLow: CGFloat
        if pinnedLow, !pinnedHigh {
            moveLow = 0
        } else if pinnedHigh, !pinnedLow {
            moveLow = shed
        } else {
            moveLow = shed / 2
        }
        return Span(
            origin: origin + moveLow,
            extent: extent - shed,
            refusal: nil
        )
    }
}
