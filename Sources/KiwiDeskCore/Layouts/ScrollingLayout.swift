import CoreGraphics

/// Niri/PaperWM-style scrolling columns.
///
/// Windows sit in an infinite row (horizontal orientation) or
/// column (vertical) of fixed-size slots. The **focus anchor**
/// decides where the focused slot rests, applied on *every* focus
/// change (#239): `center`/`start`/`end` re-seat it at a fixed
/// resting position (centred, or flush against the leading
/// left/top or trailing right/bottom edge — `start`/`end` are
/// relative to the scroll axis), then clamp so no empty
/// margin shows past the row ends; `follow` (the default) pans
/// the minimum to reveal the focus from where the viewport
/// already was (#66) — up/down mirror, an already-visible slot
/// doesn't move, the side you came from stays open — and when
/// the row moves underneath an unchanged focus instead (a slot
/// resize re-positions every slot), it holds that slot's place
/// on screen rather than its own number (#966,
/// `ScrollingLayout+Offset.heldBase`). Ends snap to the screen
/// edge. With the indicator bar enabled its strip is carved out
/// of the usable area first, so windows and bar never overlap.
///
/// macOS constrains what frames it will apply, so materialized
/// frames pin while the viewport *offset* stays the ideal,
/// unpinned value (keeping the up/down scroll math symmetric).
/// The clamp form is chosen **per edge** (#878): a *blocked*
/// edge — one with another screen beyond it
/// (`LayoutContext.screenNeighbors`), or the vertical top,
/// which macOS walls off itself (#139, an accepted OS-blocked
/// limitation, see docs/design-decisions.md) — is a hard stop,
/// where a scrolled-out slot stops flush at the border, fully
/// on its own screen, and stacks behind the viewport; frames
/// are global and macOS cannot clip another app's window, so
/// an overhang there would render on the neighbor screen. An
/// *open* edge lets the slot overhang into the void with an
/// `edgePeek` sliver still visible, because macOS clamps fully
/// offscreen frames to its own undocumented minimum anyway
/// (#142) — pinning above that minimum keeps every target
/// achievable. Neither form ever resizes a slot.
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
        let horizontal = context.scrolling.axisIsHorizontal

        // A single window always fills the whole window area —
        // unless its app refuses that size (#677): a lone
        // window has no neighbors to re-pack against, so the
        // answered size is CENTERED instead (the monocle
        // treatment; a symmetric gap reads deliberate).
        if windows.count == 1, let only = windows.first {
            return [
                only: context.sizeBounds[only]?
                    .centered(in: area) ?? area
            ]
        }

        let metrics = Self.metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        let offset = Self.offset(
            anchor: context.scrolling.anchor,
            previous: context.scrollRest,
            focus: context.focused,
            along: metrics.along,
            size: metrics.focusedSpan,
            rowLength: metrics.rowLength,
            focusedPos: metrics.focusedPos
        )

        return frames(
            windows: windows,
            area: area,
            horizontal: horizontal,
            offset: offset,
            metrics: metrics,
            neighbors: context.screenNeighbors
        )
    }

    /// The row geometry shared by `calculateGeometry` and
    /// `viewportRest`: per-slot spans and positions, total
    /// row length, and the focused slot's position along the
    /// scroll axis — nil when the focused window has no slot in
    /// the row (a floating window, or nothing focused), so the
    /// offset math knows there is nothing to scroll into view
    /// (#141). `size` is the uniform ask; a slot's span differs
    /// from it only where a confirmed app bound consumed the
    /// ask (#677), which is what re-packs the row so neighbors
    /// close a refusal's gap.
    struct Metrics {
        let along: CGFloat
        let size: CGFloat
        let spans: [CGFloat]
        let positions: [CGFloat]
        let rowLength: CGFloat
        let focusedPos: CGFloat?
        let focusedSpan: CGFloat
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
        // Honour the global floor: a scrolling slot never resolves
        // below minWindowSize, but never wider than the axis — so a
        // small fraction (e.g. 5% of a narrow display) falls back to
        // minWindowSize. Note BSP/Stack/Grid use minWindowSize as a
        // *trigger* to spill into an OverlapStack pile; scrolling has
        // no pile (its overflow is the scroll itself), so it floors
        // the slot instead.
        let size = min(along, max(resolved, context.minWindowSize))
        // Per-slot span: the learned answer where the app has
        // refused exactly this ask (#677), the uniform size
        // everywhere else — only the scroll axis re-packs; the
        // cross axis keeps asking the full extent.
        let spans = windows.map { window -> CGFloat in
            let bound = context.sizeBounds[window]
            let consumed =
                horizontal
                ? bound?.consumedWidth(asking: size)
                : bound?.consumedHeight(asking: size)
            return consumed ?? size
        }
        var positions: [CGFloat] = []
        positions.reserveCapacity(spans.count)
        var cursor: CGFloat = 0
        for span in spans {
            positions.append(cursor)
            cursor += span + gap
        }
        let rowLength = max(cursor - gap, 0)
        let focusedIndex = context.focused.flatMap {
            windows.firstIndex(of: $0)
        }
        return Metrics(
            along: along,
            size: size,
            spans: spans,
            positions: positions,
            rowLength: rowLength,
            focusedPos: focusedIndex.map { positions[$0] },
            focusedSpan: focusedIndex.map { spans[$0] }
                ?? size
        )
    }

    /// The viewport rest `calculateGeometry` would compute for
    /// `windows`, without materializing frames (#66). Lets the
    /// caller read back the value to persist as the next tile's
    /// `Space.scrollRest`, so a focus-driven retile can restore
    /// the "previous offset" input without KiwiCore re-deriving
    /// the anchor/clamp math itself. The offset travels with the
    /// slot it was measured against, which is what `follow` reads
    /// to tell a focus change from a row that moved underneath an
    /// unchanged focus (#966) — recorded fresh on a pass that
    /// placed a slot, and carried through unchanged on a pass
    /// that placed none, where the offset itself is carried too.
    ///
    /// A lone window fills the whole area, so `calculateGeometry`
    /// ignores the offset for it — but this must still *preserve*
    /// it, not persist 0 (#155): float one of two scrolled
    /// windows and the row drops to a single tiled window; a 0
    /// here overwrites the saved offset, so unfloating rebuilds
    /// the row from home. Returning the prior rest whole keeps
    /// the viewport where it was.
    static func viewportRest(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> ScrollRest {
        guard windows.count > 1 else {
            return context.scrollRest ?? ScrollRest(offset: 0)
        }
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.axisIsHorizontal
        let metrics = metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        let value = offset(
            anchor: context.scrolling.anchor,
            previous: context.scrollRest,
            focus: context.focused,
            along: metrics.along,
            size: metrics.focusedSpan,
            rowLength: metrics.rowLength,
            focusedPos: metrics.focusedPos
        )
        guard let focus = context.focused,
            let position = metrics.focusedPos
        else {
            // No slot placed this pass (a floating focus, or
            // nothing focused): `offset` carried the previous
            // offset through (#141), so its provenance carries
            // with it — the same call the `count > 1` arm makes
            // above. Destroying a measurement that still
            // describes the offset being returned would hand the
            // next pan a rest that reads as a focus change, and
            // #966's drift would come back the moment the row
            // changed while a float held focus.
            return ScrollRest(
                offset: value,
                slot: context.scrollRest?.slot
            )
        }
        return ScrollRest(
            offset: value,
            focus: focus,
            position: position
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
        let horizontal = context.scrolling.axisIsHorizontal
        let m = metrics(
            for: windows,
            context: context,
            area: area,
            horizontal: horizontal
        )
        return m.rowLength > m.along
    }

    private func frames(
        windows: [WindowID],
        area: CGRect,
        horizontal: Bool,
        offset: CGFloat,
        metrics: Metrics,
        neighbors: ScreenNeighbors
    ) -> [WindowID: CGRect] {
        let along = metrics.along
        // A blocked edge — another screen beyond it, or the
        // vertical top, which macOS itself walls off (#139) — is
        // a hard stop (#878): the scrolled-out slot stops flush
        // at the border, fully on its own screen, and stacks
        // behind the viewport (the #150 pile, relocated). An
        // open edge keeps the overhang-with-sliver pin below.
        let leadingBlocked =
            horizontal ? neighbors.left : true
        let trailingBlocked =
            horizontal ? neighbors.right : neighbors.bottom
        var result: [WindowID: CGRect] = [:]
        for (index, window) in windows.enumerated() {
            let span = metrics.spans[index]
            var lead = offset + metrics.positions[index]
            // On an open edge, pin what macOS would refuse
            // anyway (#142): (almost) fully offscreen frames
            // clamp to its own title-bar minimum. An unreachable
            // target makes every retile re-issue the frame past
            // the ±2pt tolerance, so far slots keep `edgePeek`
            // visible at the edge. The peek caps at the slot's
            // own span: a slot smaller than `edgePeek` (possible
            // via `.fraction`, whose 5% floor has no point
            // minimum) pins fully visible instead of displacing
            // already-visible slots — with the cap, the focused
            // slot is provably never touched: the offset clamps
            // already hold its lead in [0, along - focusedSpan]
            // using the slot's OWN span, which is exactly the
            // hard stop's bound here, and the open form's is
            // looser still (peek ≤ span on both ends).
            let peek = min(Self.edgePeek, span)
            lead = min(
                lead,
                trailingBlocked ? along - span : along - peek
            )
            lead = max(
                lead,
                leadingBlocked ? 0 : peek - span
            )
            result[window] =
                horizontal
                ? CGRect(
                    x: area.minX + lead,
                    y: area.minY,
                    width: span,
                    height: area.height
                )
                : CGRect(
                    x: area.minX,
                    y: area.minY + lead,
                    width: area.width,
                    height: span
                )
        }
        return result
    }
}
