import CoreGraphics

/// The ledger's read-only views, split at the file ceiling: the
/// geometry view, the probe gate and the overlay pin's
/// candidate view. The learning ladder stays in
/// `SizeBoundLearner.swift`, the unlearning in
/// `SizeBoundLearner+Invalidation.swift`.
extension SizeBoundLearner {
    /// The confirmed bound for a window, nil while unproven.
    /// The only view GEOMETRY may consume — the layouts'
    /// re-pack and centering, and the retile skip.
    func bound(for id: WindowID) -> EffectiveSizeBound? {
        bounds[id].map {
            EffectiveSizeBound(
                width: $0.width,
                height: $0.height
            )
        }
    }

    /// Whether a post-settle probe is worth an AX read
    /// (#677): the last ask exists, some axis of it is off the
    /// window's current state frame (a refusal, or an echo not
    /// yet landed), and that axis is not already believed. The
    /// common settle — a complying window whose echo landed —
    /// answers false, so probing costs nothing there.
    func wantsProbe(
        _ id: WindowID,
        currentSize: CGSize
    ) -> Bool {
        guard let ask = lastAsks[id] else { return false }
        let asked = ask.size
        let believed = bound(for: id)
        let widthDone =
            EffectiveSizeBound.matches(
                currentSize.width,
                asked.width
            )
            || believed?.consumedWidth(asking: asked.width)
                != nil
        let heightDone =
            EffectiveSizeBound.matches(
                currentSize.height,
                asked.height
            )
            || believed?.consumedHeight(asking: asked.height)
                != nil
        return !(widthDone && heightDone)
    }

    /// The unconfirmed candidates, in the same shape — for the
    /// overlay pin ONLY (#677 device QA): rendering may trust a
    /// single refusal because a wrong render self-corrects at
    /// settle, so the ring stops riding out on the second probe
    /// instead of the third — and for the placement bounce's
    /// size arm (#1161), on the same ground: a wrong candidate
    /// costs one clickless focus, which the next click or two
    /// seconds heal. Geometry must not consume this — a wrong
    /// candidate would misplace real windows.
    func candidateBound(
        for id: WindowID
    ) -> EffectiveSizeBound? {
        candidates[id].map {
            EffectiveSizeBound(
                width: $0.width,
                height: $0.height
            )
        }
    }
}
