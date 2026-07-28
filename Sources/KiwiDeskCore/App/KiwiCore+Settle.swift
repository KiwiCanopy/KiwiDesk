/// What runs when the last animation stops
/// (`AnimationEngine.onAllAnimationsEnded`).
///
/// The engine offers a single callback slot by design, so this
/// method IS the dispatch. It lives here rather than beside any
/// one client: it now serves three subsystems (z-order, focus,
/// borders), and nesting it under one of them hid it from the
/// other two.
extension KiwiCore {
    /// Fork this into a real dispatcher when a client needs
    /// something this shape cannot express: to be **run
    /// conditionally** on state the dispatcher would have to
    /// know, to be **ordered** against another runner, or to be
    /// **scoped** narrower than the global count-zero signal
    /// (per-monitor, per-space).
    ///
    /// Stated as properties rather than as a list of who is
    /// excused, deliberately: a trigger list that grows an
    /// exemption per client stops being a rule. Today none of the
    /// three trips them — the two raises carry their own pending
    /// flags and re-validate at fire time, and the border re-sync
    /// only arms a deferred task.
    ///
    /// Order-independence is the one property worth re-checking
    /// when adding a runner. The two raises are order-insensitive
    /// (the z-order restore's async pile raises end by
    /// re-asserting the focused window on top, healing any
    /// interleaving with the synchronous focus raise). The border
    /// re-sync only schedules, so it cannot interleave here —
    /// though its body can still land while a long pile raise is
    /// draining (`performZOrderSequence` walks a background AX
    /// queue at 1–20 ms a window), leaving ring and mark one
    /// restack behind until the next event. Harmless, and the
    /// next event is close.
    func animationsDidSettle() {
        runPendingZOrderRestore()
        runPendingFocusRaise()
        scheduleBorderResync()
    }
}
