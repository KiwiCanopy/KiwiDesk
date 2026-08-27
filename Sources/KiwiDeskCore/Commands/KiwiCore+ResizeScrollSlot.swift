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
    /// Two things outrank the ceiling, and both are about not
    /// destroying a value the user chose. The floor wins a
    /// contradiction — on a display narrower than the effective
    /// minimum, clamping down to the drawn area would cross the
    /// floor #933 exists to hold. And the CURRENT size wins:
    /// `scroll.set_slot_size(2000)` on a 1512pt screen is a
    /// deliberate statement that survives undocking, so a
    /// resize press may refuse to grow it further but must
    /// never quietly rewrite it downward — which is exactly the
    /// harm `docs/design-decisions.md` cites when it rules the
    /// cap out of `ScrollSize`. A shrink from such a value
    /// steps down by its own delta like any other.
    ///
    /// The focused window's learned app maximum (#1055) joins
    /// the ceiling: one slot size serves the whole row, so a
    /// grow past what the focused window's app will perform
    /// only slides the neighbors aside for a span the app then
    /// refuses — the overshoot-and-re-pack dance the issue's
    /// repro A shows. A grow the APP ceiling truncates cues
    /// `ownMaximum` on the focused window — the refusal has a
    /// window and a reason to name. A grow the VIEWPORT
    /// truncates stays deliberately silent: nothing is being
    /// protected there but the screen itself, and naming a
    /// phantom neighbor is the trap `reportResizeRefusal`'s
    /// grow arm already stands down from; a viewport-limit cue
    /// is its own change, with its own case, renderer and
    /// localized string.
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
        let requested = current + CGFloat(delta)
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
        let appMax = space.focused.flatMap {
            effectiveMaxSize(of: $0, axis: axis)
        }
        // Floored at `current` so the app ceiling never REDUCES
        // the slot: one slot size serves the whole row, so
        // trimming it to the focused window's maximum would
        // visibly shrink every NEIGHBOR on a grow press. At or
        // past the ceiling a grow refuses instead. The viewport
        // trim below is different by construction — the drawn
        // area binds every window alike.
        let appCeiling = appMax.map {
            max(CGFloat($0), current)
        }
        let limit = min(drawnAlong, appCeiling ?? .infinity)
        let ceiling = max(
            limit,
            CGFloat(effectiveMin),
            configured
        )
        let clamped = min(
            max(requested, CGFloat(effectiveMin)),
            ceiling
        )
        if delta < 0,
            clamped > requested + Self.resizeTruncationEpsilon,
            let focused = space.focused
        {
            refuseShrinkAtMinimum(focused, axis: axis)
        }
        // The cue asks WHICH limit truncated the grow: the app
        // ceiling cues (a window and a reason to name), the
        // viewport stays silent (header). `appMax < drawnAlong`
        // is that discrimination — it holds even when a banked
        // `configured` above the ceiling is what the arithmetic
        // clamped at, because the reason the slot cannot grow
        // is still the app's own maximum.
        if delta > 0,
            clamped < requested - Self.resizeTruncationEpsilon,
            let appMax,
            CGFloat(appMax) < drawnAlong,
            let focused = space.focused
        {
            refuseGrowAtMaximum(focused, axis: axis)
        }
        writeSlotSize(
            .points(clamping: clamped),
            for: space.id
        )
    }
}
