import CoreGraphics

/// Niri/PaperWM-style scrolling columns.
///
/// Windows sit in an infinite row (horizontal orientation) or
/// column (vertical) of fixed-size slots. Focus moves scroll the
/// viewport the minimal amount needed to bring the focused slot
/// fully into view (#66) — never more, so up and down are
/// mirror images of each other. The anchor only matters the
/// first time a space scrolls (or after a mode switch), seeding
/// where the initial focused slot sits; from then on the
/// viewport just tracks focus. Slots at the ends snap to the
/// screen edge so no empty margin appears. With the indicator
/// bar enabled its strip is carved out of the usable area
/// first, so windows and bar never overlap.
///
/// macOS constrains what frames it will apply, so materialized
/// frames pin while the viewport *offset* stays the ideal,
/// unpinned value (keeping the up/down scroll math symmetric):
/// a vertical row scrolled past the top pins at the border —
/// its upper strip peeks — because nothing may go above the top
/// screen edge (an accepted OS-blocked limitation, see
/// docs/design-decisions.md); and a slot scrolled far past any
/// other edge pins with an `edgePeek` sliver still visible,
/// because macOS clamps fully offscreen frames to its own
/// undocumented minimum anyway (#142) — pinning above that
/// minimum keeps every target achievable.
public struct ScrollingLayout: LayoutSystem {
    /// Visible sliver of a slot scrolled far past a screen edge
    /// (#142): the WindowServer's clamp floor plus this
    /// sliver's own margin (see
    /// `WindowServerFacts.visibilityFloor`). Sitting safely
    /// above the floor keeps every pinned target achievable,
    /// so the retile tolerance can settle instead of
    /// re-issuing unreachable frames forever.
    static let edgePeek: CGFloat =
        WindowServerFacts.visibilityFloor + 8

    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }

        // The area left for windows after the bar strip.
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.barAxisIsHorizontal

        // A single window always fills the whole window area.
        if windows.count == 1, let only = windows.first {
            return [only: area]
        }

        let metrics = Self.metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        let offset = Self.offset(
            anchor: context.scrolling.anchor,
            previous: context.scrollOffset,
            along: metrics.along,
            size: metrics.size,
            rowLength: metrics.rowLength,
            focusedPos: metrics.focusedPos
        )

        return frames(
            windows: windows,
            area: area,
            horizontal: horizontal,
            offset: offset,
            stride: metrics.stride,
            size: metrics.size
        )
    }

    /// The row geometry shared by `calculateGeometry` and
    /// `viewportOffset`: slot size, stride, total row length, and
    /// the focused slot's position along the scroll axis — nil
    /// when the focused window has no slot in the row (a floating
    /// window, or nothing focused), so the offset math knows there
    /// is nothing to scroll into view (#141).
    struct Metrics {
        let along: CGFloat
        let size: CGFloat
        let stride: CGFloat
        let rowLength: CGFloat
        let focusedPos: CGFloat?
    }

    static func metrics(
        for windows: [WindowID],
        context: LayoutContext,
        area: CGRect,
        horizontal: Bool
    ) -> Metrics {
        let gap =
            horizontal
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let along = horizontal ? area.width : area.height
        let resolved = context.scrolling.slotSize.resolved(
            along: along,
            horizontal: horizontal
        )
        // Honour the global floor: a scrolling slot never tiles
        // below minWindowSize (the same guard BSP/Stack/Grid keep),
        // but never wider than the axis. So a small fraction (e.g.
        // 5% of a narrow display) falls back to minWindowSize.
        let size = min(along, max(resolved, context.minWindowSize))
        let stride = size + gap
        let count = CGFloat(windows.count)
        let rowLength = count * size + (count - 1) * gap
        let focusedIndex = context.focused.flatMap {
            windows.firstIndex(of: $0)
        }
        return Metrics(
            along: along,
            size: size,
            stride: stride,
            rowLength: rowLength,
            focusedPos: focusedIndex.map {
                CGFloat($0) * stride
            }
        )
    }

    /// The viewport offset `calculateGeometry` would compute for
    /// `windows`, without materializing frames (#66). Lets the
    /// caller read back the value to persist as the next tile's
    /// `Space.scrollOffset`, so a focus-driven retile can restore
    /// the "previous offset" input without KiwiCore re-deriving
    /// the anchor/clamp math itself.
    ///
    /// A lone window fills the whole area, so `calculateGeometry`
    /// ignores the offset for it — but this must still *preserve*
    /// it, not persist 0 (#155): float one of two scrolled
    /// windows and the row drops to a single tiled window; a 0
    /// here overwrites the saved offset, so unfloating rebuilds
    /// the row from home. Returning the prior offset keeps the
    /// viewport where it was.
    static func viewportOffset(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> CGFloat {
        guard windows.count > 1 else {
            return context.scrollOffset ?? 0
        }
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.barAxisIsHorizontal
        let metrics = metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        return offset(
            anchor: context.scrolling.anchor,
            previous: context.scrollOffset,
            along: metrics.along,
            size: metrics.size,
            rowLength: metrics.rowLength,
            focusedPos: metrics.focusedPos
        )
    }

    /// Whether the row is longer than the viewport, so slots pile
    /// up at the edges and their stacking matters (#150). A row
    /// that fits entirely shows no overlap, so a swap within it
    /// cannot scramble the edge piles' z-order — there is nothing
    /// to restore. A superset of "the swapped pair touches a
    /// pile": the focus that moved in a swap is always panned
    /// fully into view, so a per-slot test would gate on the
    /// other window's transient position; the overflow test is
    /// cheaper and never misses a real scramble.
    static func rowOverflows(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> Bool {
        guard windows.count > 1 else { return false }
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.barAxisIsHorizontal
        let m = metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        return m.rowLength > m.along
    }

    /// The viewport offset for a focus at `focusedPos`, given the
    /// offset from the last tile (`previous`).
    ///
    /// Scroll-into-view (#66): if the focused slot is already
    /// fully visible at `previous`, the viewport does not move at
    /// all — panning only ever happens by the minimal amount
    /// needed to reveal the newly focused slot, so stepping focus
    /// up is the exact mirror of stepping it down. `previous ==
    /// nil` (a space that has never scrolled, or just switched
    /// into scrolling mode) falls back to the anchor's preferred
    /// resting position instead, so the very first tile still
    /// respects `scroll.set_anchor` — unless `focusedPos` is
    /// also nil (no slot to anchor on), which rests at the row
    /// start.
    static func offset(
        anchor: ScrollingParams.Anchor,
        previous: CGFloat?,
        along: CGFloat,
        size: CGFloat,
        rowLength: CGFloat,
        focusedPos: CGFloat?
    ) -> CGFloat {
        var target: CGFloat
        if let focusedPos {
            // The range of offsets that keep the focused slot
            // fully inside the viewport: sliding it any further
            // would clip its leading or trailing edge.
            let visibleMin = -focusedPos
            let visibleMax = along - size - focusedPos
            if let previous {
                target = min(
                    max(previous, visibleMin),
                    visibleMax
                )
            } else {
                target = anchorOffset(
                    anchor: anchor,
                    along: along,
                    size: size,
                    focusedPos: focusedPos
                )
                target = min(
                    max(target, visibleMin),
                    visibleMax
                )
            }
        } else {
            // The focused window has no slot in the row (a
            // floating window, or nothing focused): there is
            // nothing to scroll into view, so the viewport
            // stays put instead of snapping home (#141). A
            // never-scrolled space rests at the row start —
            // deliberately consuming the anchor seed (the
            // persist loop writes the 0 back): re-seeding on
            // the next slotted focus isn't worth an optional
            // return through the #66 loop for this niche.
            target = previous ?? 0
        }

        // Boundary awareness: never reveal empty margin past the
        // row ends.
        guard rowLength > along else { return 0 }
        return min(max(target, along - rowLength), 0)
    }

    /// The anchor's preferred resting position for a freshly
    /// scrolled focus, before visibility/boundary clamping.
    private static func anchorOffset(
        anchor: ScrollingParams.Anchor,
        along: CGFloat,
        size: CGFloat,
        focusedPos: CGFloat
    ) -> CGFloat {
        switch anchor {
        case .center:
            return (along - size) / 2 - focusedPos
        case .left:
            return -focusedPos
        case .right:
            return along - size - focusedPos
        }
    }

    private func frames(
        windows: [WindowID],
        area: CGRect,
        horizontal: Bool,
        offset: CGFloat,
        stride: CGFloat,
        size: CGFloat
    ) -> [WindowID: CGRect] {
        let along = horizontal ? area.width : area.height
        var result: [WindowID: CGRect] = [:]
        for (index, window) in windows.enumerated() {
            var lead = offset + CGFloat(index) * stride
            // Pin what macOS would refuse anyway (#139/#142):
            // above the top border it applies nothing at all,
            // and (almost) fully offscreen frames clamp to its
            // own title-bar minimum. An unreachable target makes
            // every retile re-issue the frame past the ±2pt
            // tolerance, so far slots keep `edgePeek` visible at
            // the trailing edge and (horizontal only) at the
            // leading edge; the vertical top stays a hard wall
            // at 0. The peek caps at the slot size: a slot
            // smaller than `edgePeek` (possible via `.fraction`,
            // whose 5% floor has no point minimum) pins fully
            // visible instead of displacing already-visible
            // slots — with the cap, the focused slot is provably
            // never touched (its lead stays in [0, along-size]).
            let peek = min(Self.edgePeek, size)
            lead = min(lead, along - peek)
            lead =
                horizontal
                ? max(lead, peek - size)
                : max(lead, 0)
            result[window] =
                horizontal
                ? CGRect(
                    x: area.minX + lead,
                    y: area.minY,
                    width: size,
                    height: area.height
                )
                : CGRect(
                    x: area.minX,
                    y: area.minY + lead,
                    width: area.width,
                    height: size
                )
        }
        return result
    }
}
