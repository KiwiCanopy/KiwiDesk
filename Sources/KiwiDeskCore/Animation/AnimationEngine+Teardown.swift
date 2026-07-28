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

    /// Stops everything, snapping to targets when enabled.
    /// Without `snapToTargets`, a window mid-exit-slide (#207)
    /// is left half-visible until a retile re-parks it —
    /// production callers should snap.
    public func cancelAll(snapToTargets: Bool = false) {
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
