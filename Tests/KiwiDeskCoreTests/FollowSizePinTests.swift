import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The #677 border-honesty correction: a tick whose animation
/// re-asks a refused size renders the commanded ORIGIN at the
/// learned answer, for the ring and the mark alike — the
/// decision is `FollowSource.renderFrame`, and the pin is
/// computed once by `TilingEngine.animationSizePin(for:)`.
/// Both managers are driven here because the shared switch
/// cannot see a guard bolted beside one `follow` body.
@Suite("Follow size pin (#677)")
@MainActor
struct FollowSizePinTests {
    private let tick = CGRect(
        x: 40,
        y: 40,
        width: 900,
        height: 300
    )
    private let pin = SizePin(width: 715)

    @Test("A pinned tick renders the answer on the ring")
    func pinnedTickCorrectsRing() {
        let border = BorderManager()
        border.sync([
            BorderManager.Spec(
                window: WindowID(1),
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 400,
                    height: 300
                ),
                colorHex: "#FF0000",
                width: 4,
                cornerStyle: .rounded
            )
        ])
        border.isAnimating = { _ in true }
        border.follow(
            WindowID(1),
            windowFrame: tick,
            source: .animationTick,
            pin: pin
        )
        // Origin commanded, width answered, height untouched:
        // the frame the window will actually hold.
        #expect(
            border.lastFrame(WindowID(1))
                == CGRect(x: 40, y: 40, width: 715, height: 300)
        )
    }

    @Test("A pinned tick renders the answer on the mark")
    func pinnedTickCorrectsMark() {
        let manager = StickyMarkManager()
        manager.sync([
            StickyMarkManager.Spec(
                window: WindowID(1),
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 400,
                    height: 300
                )
            )
        ])
        manager.isAnimating = { _ in true }
        manager.follow(
            WindowID(1),
            windowFrame: tick,
            source: .animationTick,
            pin: pin
        )
        #expect(
            manager.lastFrame(WindowID(1))
                == CGRect(x: 40, y: 40, width: 715, height: 300)
        )
    }

    @Test("An echo ignores the pin — it is already reality")
    func echoIgnoresPin() {
        let border = BorderManager()
        border.sync([
            BorderManager.Spec(
                window: WindowID(1),
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 400,
                    height: 300
                ),
                colorHex: "#FF0000",
                width: 4,
                cornerStyle: .rounded
            )
        ])
        border.skyLightActive = false
        border.isAnimating = { _ in false }
        let echo = CGRect(x: 8, y: 8, width: 830, height: 300)
        border.follow(
            WindowID(1),
            windowFrame: echo,
            source: .axEcho,
            pin: pin
        )
        #expect(border.lastFrame(WindowID(1)) == echo)
    }

    @Test("The production tee threads the pin to the ring")
    func productionTeeThreadsThePin() throws {
        // The wire the hand-built-pin tests cannot see
        // (guard-prover, 2026-08-18): `KiwiCore+Bootstrap`'s
        // `onFrameApplied` tee must COMPUTE the pin and pass
        // it — a tee passing nil ships green through every
        // other test in this suite.
        guard let screen = NSScreen.main else { return }
        let core = makeTestCore()
        let w = WindowID(1)
        core.borders.sync([
            BorderManager.Spec(
                window: w,
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 715,
                    height: 800
                ),
                colorHex: "#FF0000",
                width: 4,
                cornerStyle: .rounded
            )
        ])
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        for _ in 0..<2 {
            core.tiler.boundLearner.recordAsk(w, size: asked)
            core.tiler.boundLearner.observe(
                w,
                currentSize: answered
            )
        }
        core.tiler.animation.animate(
            window: w,
            on: screen,
            from: CGRect(x: 0, y: 0, width: 715, height: 800),
            to: CGRect(x: 50, y: 0, width: 900, height: 800)
        )
        core.tiler.onFrameApplied(
            w,
            CGRect(x: 20, y: 0, width: 800, height: 800)
        )
        // Commanded origin, learned width: the tee computed
        // and threaded the pin.
        #expect(
            core.borders.lastFrame(w)
                == CGRect(x: 20, y: 0, width: 715, height: 800)
        )
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("The engine pins only a matching in-flight target")
    func enginePinsMatchingTarget() throws {
        guard let screen = NSScreen.main else { return }
        let core = makeTestCore()
        let w = WindowID(1)
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        for _ in 0..<2 {
            core.tiler.boundLearner.recordAsk(w, size: asked)
            core.tiler.boundLearner.observe(
                w,
                currentSize: answered
            )
        }
        // No animation in flight: nothing to correct.
        #expect(core.tiler.animationSizePin(for: w) == nil)
        // In flight toward the refused ask: the width pins.
        core.tiler.animation.animate(
            window: w,
            on: screen,
            from: CGRect(
                x: 0,
                y: 0,
                width: 715,
                height: 800
            ),
            to: CGRect(x: 50, y: 0, width: 900, height: 800)
        )
        #expect(
            core.tiler.animationSizePin(for: w)
                == SizePin(width: 715)
        )
        // In flight toward a NEW ask: probe honestly, no pin.
        core.tiler.animation.animate(
            window: w,
            on: screen,
            from: CGRect(
                x: 0,
                y: 0,
                width: 715,
                height: 800
            ),
            to: CGRect(x: 50, y: 0, width: 800, height: 800)
        )
        #expect(core.tiler.animationSizePin(for: w) == nil)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("A single refusal already pins the second probe")
    func candidatePinsSecondProbe() throws {
        // Rendering may trust an unconfirmed candidate (#677
        // device QA): the second probe's animation re-asks the
        // once-refused size, and without this the ring rode out
        // on it too — the eye saw two dances where one is the
        // floor. Geometry stays confirmed-only; only the pin
        // takes the fallback.
        guard let screen = NSScreen.main else { return }
        let core = makeTestCore()
        let w = WindowID(1)
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        core.tiler.boundLearner.recordAsk(w, size: asked)
        core.tiler.boundLearner.observe(
            w,
            currentSize: answered
        )
        #expect(core.tiler.sizeBound(for: w) == nil)
        core.tiler.animation.animate(
            window: w,
            on: screen,
            from: CGRect(
                x: 0,
                y: 0,
                width: 715,
                height: 800
            ),
            to: CGRect(x: 50, y: 0, width: 900, height: 800)
        )
        #expect(
            core.tiler.animationSizePin(for: w)
                == SizePin(width: 715)
        )
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
