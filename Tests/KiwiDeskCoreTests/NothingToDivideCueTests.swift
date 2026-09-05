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
        // could not reach this guard — a horizontal master
        // zone's weight axis IS the split axis, so a press
        // there is the master ratio or nothing.)
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
        let seen = refusals(core) {
            core.execute(
                "resize",
                args: [.string("y"), .number(-200)]
            )
        }
        #expect(seen == [.nothingToDivide(WindowID(1))])
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
