import AppKit
import CoreGraphics

/// Per-frame stepping and watchdog progression for `AnimationEngine`
/// (#611, `.claude/rules/input-and-animation.md`).
extension AnimationEngine {
    func tick(display: DisplayID, dt: TimeInterval) {
        guard var perWindow = animations[display],
            !perWindow.isEmpty
        else {
            drivers[display]?.stop()
            return
        }
        for (id, var animation) in perWindow {
            var settled = animation.step(dt: dt)
            if animation.takeNonFiniteNotice() {
                onLog(
                    "animation: \(id) held a non-finite frame, "
                        + "snapped to its target"
                )
            }
            // Settle watchdog force-settles stuck animations (#611).
            if !settled, animation.isOverdue {
                animation.forceSettle()
                settled = true
                onLog(
                    "animation: \(id) did not settle in "
                        + String(format: "%.1f", animation.age)
                        + "s of motion, snapped to its target"
                )
            }
            if settled {
                apply(id, animation.frame, true)
                perWindow[id] = nil
                clearState(id)
                onWindowSettled(id, animation.frame)
                onAnimationEnd(id)
            } else {
                // Stepwise size stepping per axis (#45, #47, #593).
                let held =
                    heldSize[id]
                    ?? Self.rounded(animation.frame).size
                let stepped = SizeStep.step(
                    policy: sizePolicy,
                    sizing: animation.sizing,
                    held: held,
                    target: animation.targetFrame.size,
                    spring: animation.frame.size,
                    pastHalfway: animation.pastHalfway,
                    rateHz: storedSizeRateHz,
                    elapsed: sizeElapsed[id] ?? 0,
                    dt: dt
                )
                sizeElapsed[id] = stepped.elapsed
                let size = stepped.size
                let previous = heldSize[id]
                heldSize[id] = size
                let frame = CGRect(
                    x: animation.frame.origin.x.rounded(),
                    y: animation.frame.origin.y.rounded(),
                    width: size.width.rounded(),
                    height: size.height.rounded()
                )
                let setSize =
                    previous.map {
                        $0.width.rounded() != frame.width
                            || $0.height.rounded() != frame.height
                    } ?? true
                if setSize || lastApplied[id] != frame {
                    lastApplied[id] = frame
                    apply(id, frame, setSize)
                }
                perWindow[id] = animation
            }
        }
        animations[display] = perWindow
        if perWindow.isEmpty {
            drivers[display]?.stop()
            notifyIfIdle()
        }
    }

    /// Fires `onAllAnimationsEnded` when all display animations finish.
    func notifyIfIdle() {
        if activeCount == 0 {
            onAllAnimationsEnded()
        }
    }

    /// Validates finite, positive renderable frame boundaries.
    nonisolated static func isRenderable(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
    }

    /// Rounds rect components to nearest integer points. Settle
    /// compares ROUNDED frames: comparing raw spring output to a
    /// rounded applied frame kept animations alive for dozens of
    /// extra frames chasing sub-point deltas.
    static func rounded(_ frame: CGRect) -> CGRect {
        CGRect(
            x: frame.origin.x.rounded(),
            y: frame.origin.y.rounded(),
            width: frame.width.rounded(),
            height: frame.height.rounded()
        )
    }
}
