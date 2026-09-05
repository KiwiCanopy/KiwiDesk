import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A resize press that finds the focused window alone in the
/// group its axis divides says so (#1258). Four sites across
/// three layouts were silent, which reads as a broken shortcut
/// rather than "there is one window here".
///
/// The assertions read the `ResizeRefusal` STRUCTURE rather than
/// rendered text, so no locale is pinned (#96); one swapped to
/// the sentence would owe it (#740).
@Suite("Nothing to divide (#1258)")
@MainActor
struct NothingToDivideCueTests {
    /// Pinned display (#531), gaps (#660) and the minimum every
    /// clamp below is measured against.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-nothing-divide-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.tiler.settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(
                top: 10,
                bottom: 10,
                left: 10,
                right: 10
            ),
            inner: Gaps.Inner(horizontal: 16, vertical: 16)
        )
        #expect(core.tiler.settings.minWindowSize == 300)
        return core
    }

    private func space(
        _ core: KiwiCore,
        windows: UInt32,
        mode: String
    ) -> Space {
        for id in 1...windows {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let id = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(id.raw), .string(mode)]
        )
        core.state.workspaces.focus(WindowID(1), in: id)
        return core.state.workspaces[id]!
    }

    private func refusals(
        _ core: KiwiCore,
        _ body: () -> Void
    ) -> [ResizeRefusal] {
        var seen: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { seen.append($0) }
        body()
        return seen
    }

    @Test("A stack window alone in its column says so")
    func stackAloneInColumn() {
        // Two windows: w2 is the stack zone's only member, so
        // its column has nothing to divide. (w1, the master,
        // does not reach this guard AT THIS stack position —
        // with the default right-hand zone the horizontal
        // master's weight axis IS the split axis. Under
        // top/bottom it is not, and a lone master reaches the
        // guard on "x".)
        let core = makeCore()
        let sp = space(core, windows: 2, mode: "stack")
        core.state.workspaces.focus(WindowID(2), in: sp.id)
        let seen = refusals(core) {
            core.execute(
                "resize",
                args: [.string("y"), .number(-100)]
            )
        }
        #expect(seen == [.nothingToDivide(WindowID(2))])
    }

    @Test("A lone track's across-axis press says so")
    func trackWithOneTrack() {
        // Every window in ONE track: the across-axis weight
        // divides a single track, which is the whole span.
        let core = makeCore()
        let sp = space(core, windows: 2, mode: "track")
        core.state.workspaces.withSpace(sp.id) {
            $0.trackBreaks = []
        }
        let seen = refusals(core) {
            core.execute(
                "resize",
                args: [.string("x"), .number(-100)]
            )
        }
        #expect(seen == [.nothingToDivide(WindowID(1))])
    }

    @Test("A window filling its track says so along the axis")
    func trackAlongItsOwnAxis() {
        // One window per track (#181), so the along-axis share
        // has a single member: the window IS its track.
        let core = makeCore()
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        _ = space(core, windows: 2, mode: "track")
        let seen = refusals(core) {
            core.execute(
                "resize",
                args: [.string("y"), .number(-100)]
            )
        }
        #expect(seen == [.nothingToDivide(WindowID(1))])
    }

    @Test("A bsp space that divides neither axis says so")
    func bspSingleWindow() {
        // #1259 left this wordless on purpose — naming an axis
        // would have been false about both. This is the string
        // that fills it.
        let core = makeCore()
        _ = space(core, windows: 1, mode: "bsp")
        // BOTH axes: gating the cue on one of them left this
        // suite green while half the wiring was dead
        // (guard-prover, 2026-09-05).
        let seen = refusals(core) {
            for axis in ["x", "y"] {
                core.execute(
                    "resize",
                    args: [.string(axis), .number(-200)]
                )
            }
        }
        #expect(
            seen == [
                .nothingToDivide(WindowID(1)),
                .nothingToDivide(WindowID(1)),
            ]
        )
    }

    @Test("A stack space with an empty stack zone says so")
    func stackWithEmptyStackZone() {
        // The fifth site, and the issue's own headline
        // arrangement (architect + code review, both confirmed
        // by measurement): the layout hands master the whole
        // region and ignores `masterRatio`, so the split-axis
        // press moved a ratio nothing renders — silently — and
        // six shrinks drew five "Minimum window size reached"
        // pills on a window filling the screen.
        let core = makeCore()
        _ = space(core, windows: 1, mode: "stack")
        let seen = refusals(core) {
            for axis in ["x", "y"] {
                core.execute(
                    "resize",
                    args: [.string(axis), .number(-300)]
                )
            }
        }
        #expect(
            seen == [
                .nothingToDivide(WindowID(1)),
                .nothingToDivide(WindowID(1)),
            ]
        )
    }

    @Test("An overflow pile answers to no ratio")
    func bspOverflowPileDividesNothing() {
        // Four windows on this display drive the third split
        // below `min_window_size`, so the layout gives up and
        // piles them. A pile answers to neither ratio, and the
        // extent test cannot see it — the cascade offsets each
        // copy, so the union outgrows every slot and the pile
        // reads as participants (code review, 2026-09-05).
        let core = makeCore()
        let sp = space(core, windows: 4, mode: "bsp")
        let frames = core.tiler.calculatedFrames(state: core.state)
        let piled = frames[WindowID(3)]!
            .intersects(frames[WindowID(4)]!)
        #expect(piled, "fixture no longer piles — retune it")
        core.state.workspaces.focus(WindowID(3), in: sp.id)
        let seen = refusals(core) {
            core.execute(
                "resize",
                args: [.string("x"), .number(-300)]
            )
        }
        // Whatever it says, it must not claim an axis divides:
        // a piled window answers to neither.
        #expect(!seen.contains(.noAxisHere(WindowID(3))))
    }

    @Test("A divided axis is untouched by the new cue")
    func aRealSplitStillReportsItsLimit() {
        // The regression pin: three bsp windows, focus one that
        // IS in the vertical split, shrink to its floor. The
        // group has something to divide, so the limit cue is
        // the one that fires.
        let core = makeCore()
        let sp = space(core, windows: 3, mode: "bsp")
        core.state.workspaces.focus(WindowID(2), in: sp.id)
        let seen = refusals(core) {
            core.execute(
                "resize",
                args: [.string("y"), .number(-200)]
            )
        }
        #expect(seen == [.ownMinimum(WindowID(2))])
    }
}
