import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The refusal half of hold-to-glide's production wiring
/// (#933/#1055, retimed #1082), on the shared
/// `HoldGlideFixture`: a real size-limit cue reaching the engine
/// and ending the hold, so the pill flashes once per hold rather
/// than once per frame. Split from `HoldRepeatWiringTests` at
/// §2.1's ceiling; which cue SITES feed the funnel at all is
/// `HoldRepeatSeamTests`' derived scan.
@MainActor
@Suite("Hold-glide refusal wiring (#933/#1082)")
struct HoldGlideRefusalWiringTests {
    @Test("A refusal reached mid-glide ends the run")
    func midGlideRefusalEndsTheRun() throws {
        // A held bsp shrink walks the ratio toward the floor;
        // the frame that gets clamped fires the real #933 cue
        // outside any binding fire, which must be the glide's
        // last — one pill per hold. That the cue is heard at all
        // there is the #1082 half: `noteResizeRefusal` gates on
        // `isFiring || isGliding`, and dropping the second term
        // leaves the pill flashing every frame with this suite's
        // older shape still green. Which cue SITES feed the
        // engine is `HoldRepeatSeamTests`' derived scan, not a
        // list here.
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", -200)"#
        )
        f.core.execute(
            "set_min_window_size",
            args: [.number(300)]
        )
        f.seedBspPair()

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.hits == .number(1))
        #expect(f.heldID != nil)
        try f.beginGlide()

        // Frames shrink further until the clamp truncates; the
        // run must end on that frame, and the frame clock with
        // it. A long `dt` so a handful of frames covers the
        // distance the old per-tick steps did.
        var frames = 0
        while f.heldID != nil {
            try f.frame(1.0 / 4)
            frames += 1
            try #require(frames < 200)
        }
        #expect(frames >= 1)
        #expect(f.frameTick == nil)
        #expect(f.core.keys.isGliding == false)
    }

    @Test("A press refused at the wall arms nothing")
    func refusedPressNeverArms() throws {
        // A floating window already at the minimum: the shrink
        // truncates, the #933 cue fires inside the press-fire,
        // and holding must not tick a pill per repeat.
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", -50)"#
        )
        f.core.execute(
            "set_min_window_size",
            args: [.number(300)]
        )
        f.core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "FloatApp",
                    frame: CGRect(
                        x: 100,
                        y: 100,
                        width: 300,
                        height: 300
                    ),
                    isFloating: true
                )
            )
        )
        let space = f.core.state.workspaces.space(
            of: WindowID(1)
        )!
        f.core.state.workspaces.focus(WindowID(1), in: space)

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.hits == .number(1))
        #expect(f.heldID == nil)
        #expect(f.ticks.isEmpty)
    }
}
