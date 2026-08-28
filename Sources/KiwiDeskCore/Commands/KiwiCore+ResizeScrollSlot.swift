import AppKit
import CoreGraphics
import Foundation

/// The scrolling half of the shared clamped resize writers
/// (#933), moved out of `KiwiCore+ResizeLimits` when the file
/// reached its ceiling. Not a pure relocation: the ceiling
/// clauses below (the drawn area rather than the layout region,
/// and a configured size outranking both) landed in the same
/// change, so read the body rather than assuming it is what
/// stood in the old file. Scrolling is the one interactive resize whose store
/// is an absolute LENGTH rather than a ratio or a share, which
/// is why it is the only one needing a ceiling as well as a
/// floor — and why it carries enough argument to want its own
/// file.
extension KiwiCore {
    /// Clamped scrolling slot-size write plus the shrink cue —
    /// shared by the keyboard `resize` and the mouse
    /// `.scrollWidth` adjustment (which previously wrote
    /// unclamped, letting a drag cross the floor the keyboard
    /// path refused).
    ///
    /// Clamped at BOTH ends, and the ceiling is not symmetry for
    /// its own sake (#966 device QA): `ScrollSize` floors a
    /// points value and does not cap it, while the layout draws
    /// `min(along, …)` — so a grow past the viewport kept
    /// inflating the STORED slot while the drawn one stood
    /// still, and the shrink that followed spent one press per
    /// invisible step before anything moved.
    ///
    /// The ceiling is the area the layout actually DRAWS into —
    /// `ScrollingParams.windowFrame`, the same carve
    /// `ScrollingLayout.metrics` caps against — not the layout
    /// region it is carved from. Capping at the region leaves
    /// the outer gaps and any bar strip bankable, which on a
    /// VERTICAL axis is the App Bar's own thickness: tens of
    /// points of slot the layout can never draw, the same defect
    /// in miniature. (The `auto`/`%` seed above still reads the
    /// region, per #537. That mismatch predates this and is not
    /// this clamp's to settle.)
    ///
    /// Since #1057 this writer is PLUMBING: it resolves the
    /// inputs — the store, the drawn area, the focused
    /// window's bounds and its actually-rendered span — and
    /// `ScrollSlotDomain.decide` owns every cap, base and
    /// refusal arm, argued on that type and pinned by
    /// `ScrollSlotDomainTests`. The headline rules it
    /// enforces: a press is measured against the focused
    /// window's DRAWN span; a press the window's bound blocks
    /// outright refuses in place (pill, no write, no neighbor
    /// moved); an oversize configured store shrinks from the
    /// drawn size on the first press but is never reduced by a
    /// grow; the floor never raises the store and the viewport
    /// truncation stays wordless.
    func writeCappedScrollSlot(
        delta: Double,
        space: Space,
        bounds: CGRect
    ) {
        let scrolling =
            tiler.settings.resolvedScrolling(for: space)
        let horizontal = scrolling.axisIsHorizontal
        let along = horizontal ? bounds.width : bounds.height
        let current = scrolling.slotSize
            .editablePoints(
                along: along,
                horizontal: horizontal
            )
        let axis = horizontal ? "x" : "y"
        let effectiveMin = max(
            Double(ScrollSize.minPoints),
            space.focused.map {
                effectiveMinSize(of: $0, axis: axis)
            } ?? 0
        )
        // Built through the same resolver `layoutInput` uses, so
        // `usable` (bounds less the outer gaps) and the bar carve
        // cannot drift from what the layout drew.
        let context = tiler.settings.context(
            bounds: bounds,
            space: space,
            sticky: []
        )
        let drawn = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        // The current size joins the ceiling only for a POINTS
        // store — the case the clause is about, where the user
        // wrote a number. `auto`/`%` resolve against the layout
        // REGION (#537) while the ceiling is the drawn area, so
        // admitting them here would re-bank the bar strip on the
        // very first press: a default `auto` on the axis
        // carrying the App Bar already resolves above what the
        // layout draws. A fraction is screen-relative anyway, so
        // it survives undocking on its own and has no stated
        // size to preserve.
        let configured: CGFloat
        if case .points = scrolling.slotSize {
            configured = current
        } else {
            configured = 0
        }
        let drawnAlong = horizontal ? drawn.width : drawn.height
        let bound = space.focused.flatMap {
            tiler.sizeBound(for: $0)
        }
        let appMax = space.focused.flatMap {
            effectiveMaxSize(of: $0, axis: axis)
        }
        let appMin: CGFloat? = bound.flatMap {
            axis == "x" ? $0.minWidth : $0.minHeight
        }
        // The span the focused window actually RENDERS: the
        // bound's consume where it pins, the viewport-capped
        // store otherwise — the base the whole decision is
        // measured against (#1057).
        let capped = min(current, drawnAlong)
        let consumed =
            axis == "x"
            ? bound?.consumedWidth(asking: capped)
            : bound?.consumedHeight(asking: capped)
        let outcome = ScrollSlotDomain.decide(
            delta: CGFloat(delta),
            stored: current,
            drawnArea: drawnAlong,
            drawnFocused: consumed ?? capped,
            configured: configured,
            globalMin: CGFloat(effectiveMin),
            appMin: appMin,
            appMax: appMax.map { CGFloat($0) }
        )
        if let focused = space.focused {
            switch outcome.refusal {
            case .ownMinimum:
                refuseShrinkAtMinimum(focused, axis: axis)
            case .ownMaximum:
                refuseGrowAtMaximum(focused, axis: axis)
            case nil:
                break
            }
        }
        if let write = outcome.write {
            writeSlotSize(
                .points(clamping: write),
                for: space.id
            )
        }
    }
}
