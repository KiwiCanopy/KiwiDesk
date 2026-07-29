import AppKit
import CoreGraphics

/// `AnimationEngine`'s per-frame stepping: the `DisplayLink`
/// callback that advances every animation on one display, the
/// idle notification that fires when the last one ends, and the
/// pixel rounding they share. Split out of `AnimationEngine.swift`
/// to keep that file under the size ceiling; the main type keeps
/// the stores, the knobs and the `animate` entry point.
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
            // The settle watchdog (#611): an animation that never
            // satisfies `settled` never leaves `animations`, and
            // `onAllAnimationsEnded` only fires at zero — so one
            // stuck window kills the signal for the session. It
            // belongs here rather than in any consumer, because a
            // consumer cannot rescue itself: its arming path is
            // behind the same dead signal. Full argument, and what
            // the bound is worth, in
            // `.claude/rules/input-and-animation.md`.
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
                // Exact target, unrounded: layout output is
                // the source of truth for the final frame.
                apply(id, animation.frame, true)
                perWindow[id] = nil
                clearState(id)
                onWindowSettled(id, animation.frame)
                onAnimationEnd(id)
            } else {
                // Stepwise size, split per axis (issue #45).
                // A shrinking axis takes its target size on the
                // first frame — mid-flight overlap clears at
                // once (siblings yielding room to a newly
                // opened window). The grow direction follows the
                // active `growPolicy`: `.throttledSmooth` (#47, the
                // default) resamples the spring each tick (or at a
                // capped rate); `.midSlide` (the legacy fallback)
                // instead lands a single size-set mid-flight, where
                // the ongoing slide masks the jump.
                // Interpolating per tick would instead make slow
                // AX responders (Electron/WebKit) re-lay-out
                // continuously and fall seconds behind, stranding
                // the window mid-size — the cap bounds that load.
                // Pure moves keep the sizes equal, so no resize is
                // emitted.
                let held =
                    heldSize[id]
                    ?? Self.rounded(animation.frame).size
                let stepped = GrowSize.step(
                    policy: growPolicy,
                    held: held,
                    target: animation.targetFrame.size,
                    spring: animation.frame.size,
                    pastHalfway: animation.pastHalfway,
                    rateHz: storedGrowRateHz,
                    elapsed: sizeElapsed[id] ?? 0,
                    dt: dt
                )
                sizeElapsed[id] = stepped.elapsed
                let size = stepped.size
                let setSize = size != heldSize[id]
                heldSize[id] = size
                let frame = CGRect(
                    x: animation.frame.origin.x.rounded(),
                    y: animation.frame.origin.y.rounded(),
                    width: size.width.rounded(),
                    height: size.height.rounded()
                )
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

    /// Fires `onAllAnimationsEnded` when nothing animates
    /// anymore, on any display.
    func notifyIfIdle() {
        if activeCount == 0 {
            onAllAnimationsEnded()
        }
    }

    /// Whether a rect can actually be animated to and applied.
    /// Pure, so it is `nonisolated` and directly testable.
    nonisolated static func isRenderable(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.width.isFinite && frame.height.isFinite
            // A negative extent is as unrenderable as a NaN one,
            // and the stability suite already rejects it — the
            // production guard should not admit a shape the tests
            // call nonsense.
            && frame.width > 0 && frame.height > 0
    }

    /// Internal, not private: a same-module extension cannot
    /// reach a `private static` across files.
    static func rounded(_ frame: CGRect) -> CGRect {
        CGRect(
            x: frame.origin.x.rounded(),
            y: frame.origin.y.rounded(),
            width: frame.width.rounded(),
            height: frame.height.rounded()
        )
    }
}
