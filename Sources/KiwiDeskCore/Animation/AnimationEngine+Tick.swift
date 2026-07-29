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
            let settled = animation.step(dt: dt)
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
                // opened window) — unless this animation was
                // started as a plain resize (#593), where nothing
                // is instantly sized and the shared edge may slide.
                // The grow direction follows the active
                // `sizePolicy`: `.throttledSmooth` (#47, the
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
                // `heldSize` stays UNROUNDED: it feeds the next
                // tick's `target <= held` direction test, and
                // rounding it would perturb that comparison.
                heldSize[id] = size
                let frame = CGRect(
                    x: animation.frame.origin.x.rounded(),
                    y: animation.frame.origin.y.rounded(),
                    width: size.width.rounded(),
                    height: size.height.rounded()
                )
                // Whether to SET the size is asked of the rounded
                // sizes, which are what actually reach the window.
                // A sub-pixel delta does not render but still
                // costs a blocking AX round-trip — the waste this
                // type's header says it skips. Without a sizing
                // promise the question never arose: a shrinking
                // axis emits the exact target, a stable value, so
                // the flag fell false after frame 1. A promised
                // pass hands back a fresh sub-pixel spring value
                // every tick, so an
                // unrounded compare marked the entire convergence
                // tail as a resize — 13 of 36 frames byte-identical
                // to their predecessor, each one a forced content
                // reflow on a slow-AX app (found in review).
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
