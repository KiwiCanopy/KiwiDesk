import CoreGraphics

/// Pure frame math for keyboard-resizing a FLOATING window:
/// `resize` on a floating focused window grows or shrinks the
/// window itself along the requested axis instead of nudging
/// the layout it does not participate in.
///
/// **A keyboard resize is SYMMETRIC, with pinned edges** (#1091,
/// owner ruling 2026-08-29). Both edges move by half the delta;
/// an edge against the boundary is PINNED and the whole delta
/// goes to the other side; with both pinned a grow refuses and
/// the caller cues, while a shrink contracts symmetrically as
/// normal.
///
/// This replaced an origin-anchored model that mirrored **a
/// mouse drag of the bottom-right corner** — the grabbed edge is
/// the anchor. That is the right model for a drag and the wrong
/// one for a keyboard: a chord has no grabbed edge, so
/// privileging the right/bottom one is arbitrary, and against a
/// screen edge it stopped the resize dead while free space sat
/// on the other side (measured: 10 further grow asks moved the
/// window 0 pt, silently, with 892 pt free to its left).
///
/// **The pinning applies to SHRINK as well as grow**, which is
/// the load-bearing half: pin only on grow and grow/shrink stops
/// being reversible at exactly the edge people park windows
/// against. Every steady state round-trips — the reversibility
/// table is on the issue.
///
/// One accepted residue, deliberate rather than overlooked:
/// reversibility does NOT hold across the step that first brings
/// a window into contact with a boundary. A window with 28 pt of
/// room on the right, grown by 100, spills the blocked 22 pt
/// leftward and pins its right edge; the following shrink then
/// comes entirely off the left and lands half a step right of
/// where it started. Bounded by half a step and confined to that
/// one transition. Do NOT answer it by remembering which way the
/// last grow went: a stored direction needs invalidating on
/// every move, mode change and display change, and buys back
/// less than it costs.
public enum FloatResize {
    /// How near an edge counts as touching it. Matches the bar
    /// clamp's own tolerance in spirit: a window within a point
    /// of the boundary has no usable room there, and treating it
    /// as free would hand it a sub-pixel share of the delta and
    /// leave the other side short.
    public static let boundaryTolerance: CGFloat = 1

    /// The size a shrink stops at: `min_window_size` when set,
    /// never below 1 pt — AppKit rejects zero/negative frames.
    /// `resized` caps this at the CURRENT size, so the floor
    /// never *lifts* a frame; growing back works from any size
    /// regardless.
    public static func shrinkFloor(
        minSize: CGFloat
    ) -> CGFloat {
        max(minSize, 1)
    }

    /// Why a GROW could not deliver what it was asked for. Both
    /// cases owe the user a cue, on #933's stated principle that
    /// a request the limit truncates is already a refusal of
    /// part of it — the shrink arm has cued on exactly that
    /// since #933, and a grow that quietly delivered 12 of an
    /// asked 100 was the same defect at the other end (code
    /// review, 2026-08-29).
    ///
    /// Shrink never sets one: it always has somewhere to
    /// contract to, and its own truncation against
    /// `min_window_size` is cued by the caller.
    public enum Refusal: Equatable {
        /// Both edges against the boundary — nothing moved.
        case blocked
        /// Moved, but by less than the delta asked for.
        case truncated
    }

    /// What a resize produced, and why it fell short if it did.
    /// Shaped after `ScrollSlotDomain.Outcome`, the house idiom
    /// for a pure decision that also has to say why it refused.
    public struct Outcome: Equatable {
        public let frame: CGRect
        public let refusal: Refusal?
    }

    /// The frame after resizing along one axis by `delta`
    /// (negative shrinks), split between both edges and pinned
    /// against `bounds`. A nil `bounds` is unbounded — no edge
    /// pins, so the delta always splits evenly.
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
