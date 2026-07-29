import AppKit

/// Teardown paths: stopping one window, stopping everything, and
/// reacting to a disconnected monitor. Split from the hot `tick`
/// core (AGENTS.md §2 file-size ceiling); shares the engine's
/// per-window bookkeeping through `clearState`.
extension AnimationEngine {
    /// Stops animating a window, leaving it where it is.
    public func cancel(window: WindowID) {
        if removeAnimation(for: window) != nil {
            clearState(window)
            onAnimationEnd(window)
            notifyIfIdle()
        }
    }

    /// Stops everything, snapping to targets when asked.
    ///
    /// **This is a test drain primitive, not a production escape
    /// hatch** — it is how a suite empties the engine so
    /// `onAllAnimationsEnded` fires without driving a real
    /// `DisplayLink` clock, and it is deliberately unwired in
    /// `Sources/` (#611). Production has no need for a global
    /// cancel: `stop()` tears down differently on purpose (retire
    /// rings, `gatherWindows()` by direct AX, then subsystems —
    /// it never wants in-flight animations snapped first),
    /// `displaysChanged()` handles the per-display case, and
    /// `cancel(window:)` covers the per-window one and *is* used
    /// in production. Non-convergence is the watchdog's job now,
    /// not a hatch nobody calls.
    ///
    /// `snapToTargets` is required rather than defaulted because
    /// `false` is the unsafe value — it leaves a window
    /// mid-exit-slide (#207) half-visible until a retile re-parks
    /// it. Wire this to a lifecycle event some day, forget the
    /// flag, and windows strand; a required parameter turns that
    /// into a compiler question, as `apply(profile:forceRetile:)`
    /// already does for the same reason.
    public func cancelAll(snapToTargets: Bool) {
        for perWindow in animations.values {
            for (id, animation) in perWindow {
                if snapToTargets {
                    apply(id, animation.targetFrame, true)
                }
                onAnimationEnd(id)
            }
        }
        let wasActive = activeCount > 0
        animations = [:]
        lastApplied = [:]
        heldSize = [:]
        sizeElapsed = [:]
        for driver in drivers.values {
            driver.stop()
        }
        if wasActive {
            onAllAnimationsEnded()
        }
    }

    /// Drops display links for disconnected monitors. Their
    /// in-flight animations complete instantly.
    public func displaysChanged() {
        let connected = Set(
            NSScreen.screens.compactMap { $0.kiwiDisplay?.id }
        )
        for display in Array(drivers.keys)
        where !connected.contains(display) {
            drivers[display]?.invalidate()
            drivers[display] = nil
            var removedAny = false
            for (id, animation) in animations[display] ?? [:] {
                apply(id, animation.targetFrame, true)
                clearState(id)
                onAnimationEnd(id)
                removedAny = true
            }
            animations[display] = nil
            if removedAny {
                notifyIfIdle()
            }
        }
    }
}
