import CoreGraphics

/// The scrolling slot resize DECISION (#1057), pure: what one
/// press writes and which refusal it cues, measured against the
/// focused window's DRAWN span rather than the stored slot.
/// `writeCappedScrollSlot` is the one caller — keyboard and
/// mouse both route through it (#933) — and stays plumbing;
/// every arm of the cap logic is a case here, unit-tested
/// directly (`ScrollSlotDomainTests`).
///
/// The drawn base is the owner-ruled rule (#1057, 2026-08-28):
/// a resize press acts on the focused WINDOW, so it is measured
/// from what that window actually renders — the store is an
/// implementation detail. Three consequences, each an arm
/// below:
/// - A press the window's learned bound blocks outright — grow
///   at its maximum, shrink at its minimum — REFUSES in place:
///   pill, no write, no neighbor moved. One slot serves the
///   whole row, and resizing the row from a window that cannot
///   follow is what made presses silently move everyone else.
/// - An OVERSIZE store (a configured slot wider than the
///   screen) shrinks from the drawn size, so the first press
///   has visible effect — while a grow still refuses, because
///   rewriting the configured value DOWNWARD on a grow is the
///   config destruction #966 ruled out.
/// - A window pinned BELOW the slot's reach (its floor above
///   the store) grows from its own drawn span, so the press
///   grows the window immediately instead of spending presses
///   walking the store up to it.
public enum ScrollSlotDomain {
    /// Which pill a refused or truncated press shows. A
    /// viewport-bound truncation stays `nil` refusal — that
    /// limit protects no window and names none (#1055's
    /// wordless ruling).
    public enum Refusal: Equatable, Sendable {
        case ownMinimum
        case ownMaximum
    }

    public struct Outcome: Equatable, Sendable {
        /// The value to store, nil when the press must touch
        /// nothing (a refusal in place).
        public let write: CGFloat?
        public let refusal: Refusal?

        public init(write: CGFloat?, refusal: Refusal?) {
            self.write = write
            self.refusal = refusal
        }
    }

    /// One press. `stored` is the resolved current store;
    /// `drawnArea` the viewport carve the layout draws into;
    /// `drawnFocused` the span the focused window actually
    /// renders (the caller reads it off the engine's computed
    /// frames — #1063 — falling back to the bound's consume of
    /// the store, then to the layout-floored
    /// `min(max(stored, globalMin), drawnArea)`);
    /// `configured` the points-store value or 0 (#966's
    /// never-reduce term); `globalMin` the floor from
    /// `min_window_size` and `ScrollSize.minPoints`; `appMin` /
    /// `appMax` the focused window's corroborated bounds.
    public static func decide(
        delta: CGFloat,
        stored: CGFloat,
        drawnArea: CGFloat,
        drawnFocused: CGFloat,
        configured: CGFloat,
        globalMin: CGFloat,
        appMin: CGFloat?,
        appMax: CGFloat?
    ) -> Outcome {
        delta > 0
            ? grow(
                delta: delta,
                stored: stored,
                drawnArea: drawnArea,
                drawnFocused: drawnFocused,
                configured: configured,
                globalMin: globalMin,
                appMax: appMax
            )
            : shrink(
                delta: delta,
                stored: stored,
                drawnArea: drawnArea,
                drawnFocused: drawnFocused,
                configured: configured,
                globalMin: globalMin,
                appMin: appMin
            )
    }

    private static let tolerance = EffectiveSizeBound
        .matchTolerance

    /// The quantum for "the clamp truncated the request" on
    /// the point-valued paths — AX frames wobble by sub-point
    /// rounding, so exact comparison would cue on noise. The
    /// ONE copy; `KiwiCore.resizeTruncationEpsilon` derives
    /// from it for the float path.
    public static let truncationEpsilon: CGFloat = 0.5

    private static func grow(
        delta: CGFloat,
        stored: CGFloat,
        drawnArea: CGFloat,
        drawnFocused: CGFloat,
        configured: CGFloat,
        globalMin: CGFloat,
        appMax: CGFloat?
    ) -> Outcome {
        // The window is AT its own maximum: nothing this press
        // could write changes it, so it refuses in place with
        // the pill — the first press, wherever the store sits.
        if let appMax, drawnFocused >= appMax - tolerance {
            return Outcome(write: nil, refusal: .ownMaximum)
        }
        // An oversize store has nothing to grow into, and
        // rewriting it DOWNWARD on a grow is the #966 config
        // destruction. Wordless: the limit is the viewport.
        if stored > drawnArea + tolerance {
            return Outcome(write: nil, refusal: nil)
        }
        // The window can grow: measure from whichever of the
        // drawn span and the store lies FORWARD of the press
        // (#1083). `drawnFocused` alone is #1057's rule and is
        // right when the window is pinned ABOVE the store — the
        // press reaches it in one go rather than walking the
        // store up. But the layout also draws a bound-pinned
        // window BELOW an oversize store, and measuring from
        // there wrote the smaller number back and trimmed the
        // row for every neighbour (a ~1160pt auto slot rewritten
        // to 765). Taking the max keeps #1057's case and makes
        // the other one impossible by construction, rather than
        // by a guard that silently swallows the press.
        let base = max(drawnFocused, stored)
        let requested = base + delta
        let ceiling = max(
            min(drawnArea, appMax ?? .infinity),
            configured,
            base
        )
        let clamped = min(max(requested, globalMin), ceiling)
        // A truncated grow cues only when the APP ceiling is
        // the binding limit; the viewport stays wordless.
        let truncated = clamped < requested - truncationEpsilon
        let appBound =
            appMax.map { $0 < drawnArea } == true
        // A press that grows nothing writes nothing — a
        // fruitless grow must never rewrite the store
        // sideways (a floor-pinned window already wider than
        // the viewport would otherwise snap the store to its
        // span).
        guard clamped > base + truncationEpsilon else {
            return Outcome(
                write: nil,
                refusal:
                    truncated && appBound ? .ownMaximum : nil
            )
        }
        return Outcome(
            write: clamped,
            refusal: truncated && appBound ? .ownMaximum : nil
        )
    }

    private static func shrink(
        delta: CGFloat,
        stored: CGFloat,
        drawnArea: CGFloat,
        drawnFocused: CGFloat,
        configured: CGFloat,
        globalMin: CGFloat,
        appMin: CGFloat?
    ) -> Outcome {
        // The window is AT its own minimum: refuse in place —
        // never snap the shared store to the floor (the
        // never-raise rule) and never shrink the neighbors
        // from a window that cannot follow.
        if let appMin, drawnFocused <= appMin + tolerance {
            return Outcome(write: nil, refusal: .ownMinimum)
        }
        // Measure from whichever of the drawn span and the
        // store lies FORWARD of the press — the mirror of the
        // grow base (#1083). `drawnFocused` alone is #1057's
        // rule and is right for an oversize store, which then
        // shrinks visibly on the FIRST press. Where the window
        // is pinned ABOVE the store instead, measuring from the
        // drawn span made a SHRINK compute a bigger number than
        // the store and raise the row; taking the min keeps
        // #1057's case and leaves the configured floor as the
        // thing that answers, WITH its pill, rather than a
        // guard swallowing the press in silence.
        let base = min(drawnFocused, stored)
        let requested = base + delta
        // The floor never raises the store (the #1055 mirror);
        // capped at STORED — not the drawn base — so a store
        // already below the floor stays put, while on a
        // display narrower than the floor (drawn under
        // `globalMin`) the floor still wins the contradiction
        // and the press refuses rather than writing a value
        // below `min_window_size`.
        // `appMin` is rule 1's alone: the caller's `globalMin`
        // already carries the effective floor, and a second
        // max here would pin a branch production cannot take.
        let floor = min(globalMin, stored)
        let clamped = max(requested, floor)
        let truncated = clamped > requested + truncationEpsilon
        // A press that shrinks nothing writes nothing — the
        // refusal-in-place twin of the grow guard.
        guard clamped < base - truncationEpsilon else {
            return Outcome(
                write: nil,
                refusal: truncated ? .ownMinimum : nil
            )
        }
        return Outcome(
            write: clamped,
            refusal: truncated ? .ownMinimum : nil
        )
    }
}
