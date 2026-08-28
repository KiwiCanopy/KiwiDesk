import CoreGraphics

/// What a believed bound lets a layout DO (#677/#1055): which
/// ask it may answer without probing (`consumedWidth/Height`),
/// which residue a slot takes (`centered`), and when a window
/// off its target is explained rather than stranded
/// (`explains`). Split from `EffectiveSizeBound.swift` at the
/// file ceiling when the Lane B generalization landed; the
/// corroboration algebra stays in the type's own file.
extension EffectiveSizeBound {
    /// The width a layout may emit in place of the `span` it
    /// is about to ask: the learned answer iff that ask is one
    /// the app refused, else the CORROBORATED bound when the
    /// ask lies beyond it (#1055 Lane B — the churn fix: one
    /// slot size serves a scrolling row, so every resize press
    /// used to mint a brand-new ask and re-run the learn dance
    /// the ladder had already answered). A per-ask entry
    /// outranks the generalization for any ask it matches —
    /// that precedence is the falsifier the ruling requires —
    /// and an ask between the bounds stays nil: a *new* ask in
    /// the unlearned range must be probed, not silently
    /// swapped, or a user widening a slot past a stale bound
    /// would never be heard (#677).
    public func consumedWidth(
        asking span: CGFloat,
        generalizing: Bool = true
    ) -> CGFloat? {
        consumed(
            entries: width,
            asking: span,
            generalizing: generalizing
        )
    }

    /// `consumedWidth`'s vertical twin.
    public func consumedHeight(
        asking span: CGFloat,
        generalizing: Bool = true
    ) -> CGFloat? {
        consumed(
            entries: height,
            asking: span,
            generalizing: generalizing
        )
    }

    /// `generalizing: false` is the forced-apply probe (#1055,
    /// owner ruling 2026-08-28): exact refused asks still
    /// consume, the corroborated-bound arms stand down, so an
    /// explicit apply genuinely re-asks the app once —
    /// `LayoutContext.probesBeyondBounds` is the one producer
    /// of a false.
    private func consumed(
        entries: [Axis],
        asking span: CGFloat,
        generalizing: Bool
    ) -> CGFloat? {
        if let exact = entries.first(where: {
            Self.matches($0.asked, span)
        }) {
            return exact.answered
        }
        guard generalizing else { return nil }
        if let max = ceiling(of: entries),
            span > max + Self.matchTolerance
        {
            return chained(entries: entries, through: max)
        }
        if let min = floor(of: entries),
            span < min - Self.matchTolerance
        {
            return chained(entries: entries, through: min)
        }
        return nil
    }

    /// The generalized answer, re-resolved ONCE through the
    /// ladder at the bound's own span (code review,
    /// 2026-08-27): the consume rewrites the ask the ladder
    /// sees — the layout emits the bound, so an app that now
    /// contradicts it (the aspect-coupled emulator after an
    /// other-axis change) mints its entry AT the bound's span,
    /// never at the configured ask. Without this chain that
    /// entry could never outrank the generalization and the
    /// row packed a stale span forever; with it, the entry at
    /// the bound answers every generalized ask, which is the
    /// falsifier the ruling requires actually engaging.
    /// Chased to a FIXED POINT, not one step (re-review,
    /// 2026-08-28): a second bound shift mints its entry at
    /// the first revision's span — (715, 650), (650, 600) —
    /// and a single-step chain would emit 650 forever. The
    /// walk is bounded by the entry count, so a pathological
    /// cycle in the ladder exits rather than spinning.
    private func chained(
        entries: [Axis],
        through bound: CGFloat
    ) -> CGFloat {
        var value = bound
        for _ in 0..<entries.count {
            guard
                let next = entries.first(where: {
                    Self.matches($0.asked, value)
                })?.answered,
                !Self.matches(next, value)
            else { break }
            value = next
        }
        return value
    }

    /// The centered residue frame for a slot this bound
    /// refuses (owner ruling on #677): per axis, the answered
    /// span centered in the slot iff the slot's span consumes;
    /// the other axis keeps the slot's extent. Nil when
    /// neither axis consumes — the slot must be asked as-is.
    /// Centered because the residue at the slot origin reads
    /// broken while a symmetric gap reads deliberate; monocle
    /// takes this for its whole slot, scrolling for a row that
    /// cannot re-pack (a single window).
    public func centered(
        in slot: CGRect,
        generalizing: Bool = true
    ) -> CGRect? {
        let width = consumedWidth(
            asking: slot.width,
            generalizing: generalizing
        )
        let height = consumedHeight(
            asking: slot.height,
            generalizing: generalizing
        )
        guard width != nil || height != nil else { return nil }
        let size = CGSize(
            width: width ?? slot.width,
            height: height ?? slot.height
        )
        return CGRect(
            x: slot.midX - size.width / 2,
            y: slot.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Whether a window sitting at `currentSize` against a
    /// retile's `targetSize` is fully explained by this bound:
    /// per axis, already within tolerance, re-asking a refused
    /// ask with the window at its learned answer, or — the
    /// #1055 generalization — a target beyond a corroborated
    /// bound with the window resting AT that bound. The retile
    /// skip consults this so a target the ladder has already
    /// answered is "already there" instead of re-issued
    /// forever (#677).
    public func explains(
        currentSize: CGSize,
        targetSize: CGSize
    ) -> Bool {
        axisExplained(
            entries: width,
            current: currentSize.width,
            target: targetSize.width
        )
            && axisExplained(
                entries: height,
                current: currentSize.height,
                target: targetSize.height
            )
    }

    private func axisExplained(
        entries: [Axis],
        current: CGFloat,
        target: CGFloat
    ) -> Bool {
        if Self.matches(current, target) { return true }
        if entries.contains(where: {
            Self.matches(target, $0.asked)
                && Self.matches(current, $0.answered)
        }) {
            return true
        }
        if let max = ceiling(of: entries),
            target > max + Self.matchTolerance,
            Self.matches(
                current,
                chained(entries: entries, through: max)
            )
        {
            return true
        }
        if let min = floor(of: entries),
            target < min - Self.matchTolerance,
            Self.matches(
                current,
                chained(entries: entries, through: min)
            )
        {
            return true
        }
        return false
    }
}
