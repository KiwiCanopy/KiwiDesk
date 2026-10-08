import AppKit

/// Animation teardown, cancellation, and display disconnection handlers.
extension AnimationEngine {
    /// Stops animating a window, leaving it where it is.
    public func cancel(window: WindowID) {
        if removeAnimation(for: window) != nil {
            ticks.forget(window)
            onAnimationEnd(window)
            notifyIfIdle()
        }
    }

    /// Stops all animations, optionally snapping windows to targets
    /// (#207, #611).
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
        ticks = WindowTickLedger()
        for driver in drivers.values {
            driver.stop()
        }
        if wasActive {
            onAllAnimationsEnded()
        }
    }

    /// Drops display links and settles in-flight animations on disconnected
    /// monitors.
    public func displaysChanged() {
        let connected = Set(
            ScreenList.all.compactMap { $0.kiwiDisplayID }
        )
        for display in Array(drivers.keys)
        where !connected.contains(display) {
            drivers[display]?.invalidate()
            drivers[display] = nil
            var removedAny = false
            for (id, animation) in animations[display] ?? [:] {
                apply(id, animation.targetFrame, true)
                ticks.forget(id)
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
