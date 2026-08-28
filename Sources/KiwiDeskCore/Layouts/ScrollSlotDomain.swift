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
    /// renders (the caller resolves it through the bound's
    /// consume, falling back to `min(stored, drawnArea)`);
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
        // The window can grow: measure from ITS span, so a
        // window pinned above the store is reached in one
        // press rather than walking the store up to it.
        let base = max(drawnFocused, min(stored, drawnArea))
        let requested = base + delta
        let ceiling = max(
            min(drawnArea, appMax ?? .infinity),
            configured,
            base
        )
        let clamped = min(max(requested, globalMin), ceiling)
        // A truncated grow cues only when the APP ceiling is
        // the binding limit; the viewport stays wordless.
        let truncated = clamped < requested - 0.5
        let appBound =
            appMax.map { $0 < drawnArea } == true
        // A press that grows nothing writes nothing — a
        // fruitless grow must never rewrite the store
        // sideways (a floor-pinned window already wider than
        // the viewport would otherwise snap the store to its
        // span).
        guard clamped > base + 0.5 else {
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
        // Measure from the drawn span (#1057's core): an
        // oversize store shrinks visibly on the FIRST press,
        // and the store is only rewritten now — the moment the
        // user deliberately resizes on this screen.
        let base = min(drawnFocused, min(stored, drawnArea))
        let requested = base + delta
        // The floor never raises the store (the #1055 mirror);
        // capped at STORED — not the drawn base — so a store
        // already below the floor stays put, while on a
        // display narrower than the floor (drawn under
        // `globalMin`) the floor still wins the contradiction
        // and the press refuses rather than writing a value
        // below `min_window_size`.
        let floor = min(
            max(globalMin, appMin ?? 0),
            stored
        )
        let clamped = max(requested, floor)
        let truncated = clamped > requested + 0.5
        // A press that shrinks nothing writes nothing — the
        // refusal-in-place twin of the grow guard.
        guard clamped < base - 0.5 else {
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
