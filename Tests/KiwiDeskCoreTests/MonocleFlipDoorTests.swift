import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// The commanded-focus door through a real core (#1391): a
/// Monocle `focus` step defers `focusWindow` to the flip's
/// midpoint, the next command lands it first, and every
/// stand-down focuses at once.
@Suite("Monocle flip door (#1391)", .serialized)
@MainActor
struct MonocleFlipDoorTests {
    /// Three tiled windows in a Monocle Space, w1 focused, the
    /// display pinned (#531) and the flip's own Reduce Motion
    /// read OFF — `makeTestCore` pins it on.
    private func makeMonocleCore(flip: Bool = true) -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1440, height: 900)
        }
        core.monocleFlip.reduceMotion = { !flip }
        core.monocleFlip.present = { _ in }
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: 1,
                        appName: "App\(id)"
                    )
                )
            )
        }
        core.state.workspaces.focus(w1, in: SpaceID(1))
        core.retile()
        return core
    }

    @Test("A Monocle step defers the focus to the midpoint")
    func stepDefersTheFocus() {
        let core = makeMonocleCore()
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.monocleFlip.isPlaying)
        #expect(core.activeSpace?.focused == w1)
        core.monocleFlip.settle()
        #expect(!core.monocleFlip.isPlaying)
        #expect(core.activeSpace?.focused == w2)
    }

    @Test("The next command lands the pending focus first")
    func nextCommandSettlesFirst() {
        let core = makeMonocleCore()
        core.execute("focus", args: [.string("right")])
        // Read from the LANDED anchor: two presses reach w3,
        // never w2 twice.
        core.execute("focus", args: [.string("right")])
        core.monocleFlip.settle()
        #expect(core.activeSpace?.focused == w3)
    }

    @Test("Settling with nothing playing is a no-op")
    func idleSettle() {
        let core = makeMonocleCore()
        core.monocleFlip.settle()
        #expect(core.activeSpace?.focused == w1)
    }

    @Test("Off, or under Reduce Motion, the focus lands at once")
    func standsDownToTheInstantSwap() {
        let off = makeMonocleCore()
        off.execute(
            "animations.set_on_monocle_focus",
            args: [.bool(false)]
        )
        off.execute("focus", args: [.string("right")])
        #expect(!off.monocleFlip.isPlaying)
        #expect(off.activeSpace?.focused == w2)

        let reduced = makeMonocleCore(flip: false)
        reduced.execute("focus", args: [.string("right")])
        #expect(!reduced.monocleFlip.isPlaying)
        #expect(reduced.activeSpace?.focused == w2)
    }

    @Test("A non-Monocle Space never flips")
    func otherLayoutsNeverFlip() {
        let core = makeMonocleCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        core.retile()
        core.execute("focus", args: [.string("right")])
        #expect(!core.monocleFlip.isPlaying)
        #expect(core.activeSpace?.focused == w2)
    }

    @Test("The plan carries the step's sign and the issued frames")
    func planReadsTheCore() throws {
        let core = makeMonocleCore()
        let (plan, current) = try #require(
            core.monocleFlipPlan(to: w2, step: 1)
        )
        #expect(current == w1)
        #expect(plan.sign == 1)
        #expect(plan.axis == .vertical)
        let frames = core.tiler.placedFrames(state: core.state)
        #expect(plan.from == frames[w1])
        #expect(plan.to.size == frames[w2]?.size)
        #expect(plan.duration == 0.45)
    }

    @Test("A named target's sign is array order")
    func namedTargetSign() throws {
        let core = makeMonocleCore()
        core.state.workspaces.focus(w3, in: SpaceID(1))
        let (plan, _) = try #require(
            core.monocleFlipPlan(to: w1, step: nil)
        )
        #expect(plan.sign == -1)
    }
}
