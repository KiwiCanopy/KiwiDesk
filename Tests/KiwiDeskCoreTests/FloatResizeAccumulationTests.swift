import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A floating `resize` accumulates against the in-flight
/// animation's TARGET (#129/#1056): `state.windows[id].frame`
/// is echo-fed, and in a test no echo ever arrives — exactly
/// the stale-geometry window a rapid second press or a
/// hold-to-repeat tick lands in. Before the fix both presses
/// based on the original frame and the second was swallowed
/// whole. The animated target is DELIBERATELY the only
/// commanded value trusted — the instant path re-bases on the
/// echo-fed frame, an accepted residue this suite pins as such
/// (the #881 stamp was tried as a base and rejected: it re-arms
/// per press, so an app that silently refuses every ask banks
/// commanded growth without bound — the argument is in
/// `KiwiCore+ResizeFloating` and `docs/accepted-limitations.md`).
@MainActor
@Suite("Floating resize accumulation (#129/#1056)")
struct FloatResizeAccumulationTests {
    private func makeFloatCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-floataccum-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "FloatApp",
                    frame: CGRect(
                        x: 100,
                        y: 100,
                        width: 500,
                        height: 400
                    ),
                    isFloating: true
                )
            )
        )
        let space = core.state.workspaces.space(
            of: WindowID(1)
        )!
        core.state.workspaces.focus(WindowID(1), in: space)
        return core
    }

    @Test("The instant path re-bases on the frame, by ruling")
    func instantPathKeepsTheEchoBase() {
        // The accepted residue, pinned so it stays a RULING: a
        // second press before the echo re-asks the same target
        // instead of compounding a commanded value nothing
        // confirmed. Whoever re-bases this path on a stored
        // commanded frame owes the banked-growth analysis in
        // `KiwiCore+ResizeFloating` first — this redding is the
        // prompt to go read it.
        let core = makeFloatCore()
        core.tiler.settings.animations.onWindowResize = false

        for _ in 0..<2 {
            let res = core.execute(
                "resize",
                args: [.string("x"), .number(50)]
            )
            #expect(res.isSuccess)
        }
        #expect(
            core.tiler.recentInstantTarget(WindowID(1))?.width
                == 550
        )
        #expect(core.state.windows[WindowID(1)]?.frame.width == 500)
    }

    @Test(
        "Animated applies accumulate against the flight target",
        .enabled(if: NSScreen.main != nil)
    )
    func animatedPathAccumulates() {
        let core = makeFloatCore()
        // `makeTestCore` pins reduceMotion false; resize
        // animation is on by default, and a screen exists, so
        // each press retargets the in-flight spring.
        #expect(
            core.tiler.settings.animations.onWindowResize
        )
        for _ in 0..<2 {
            let res = core.execute(
                "resize",
                args: [.string("x"), .number(50)]
            )
            #expect(res.isSuccess)
        }
        #expect(
            core.tiler.animation.targetFrame(window: WindowID(1))?
                .width == 600
        )
        // Drain: leave no live animation behind for later
        // suites sharing the run.
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
