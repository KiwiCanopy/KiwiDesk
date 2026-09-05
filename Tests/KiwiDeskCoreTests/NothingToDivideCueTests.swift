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
    private func makeCore(
        width: CGFloat = 1200,
        height: CGFloat = 800
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-nothing-divide-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: width, height: height)
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
        #expect(
            seen == [
                .nothingToDivide(
                    WindowID(2),
                    // The master/stack split still divides.
                    otherAxisDivides: true
                )
            ]
        )
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
        #expect(
            seen == [
                .nothingToDivide(
                    WindowID(1),
                    // Two windows share that one track, so the
                    // along axis does divide.
                    otherAxisDivides: true
                )
            ]
        )
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
        #expect(
            seen == [
                .nothingToDivide(
                    WindowID(1),
                    // A second track exists to resize across.
                    otherAxisDivides: true
                )
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
                .nothingToDivide(
                    WindowID(1),
                    otherAxisDivides: false
                ),
                .nothingToDivide(
                    WindowID(1),
                    otherAxisDivides: false
                ),
            ]
        )
    }

    @Test("An empty stack zone still points at the weights")
    func stackEmptyZoneWithDividingWeights() {
        // The sixth answer, and the reason the verdict rides the
        // case at all: two masters with a VERTICAL orientation
        // divide "y" between them while the split divides
        // nothing, so this arrangement is owed the other
        // sentence. Asserting only the `false` answer left the
        // `true` one unread — a wrong constant there would have
        // shipped green (review, 2026-09-05).
        let core = makeCore()
        let sp = space(core, windows: 2, mode: "stack")
        core.execute(
            "stack.set_master_count",
            args: [.number(2)]
        )
        core.execute(
            "stack.set_master_orientation",
            args: [.string("vertical")]
        )
        core.state.workspaces.focus(WindowID(1), in: sp.id)
        let seen = refusals(core) {
            core.execute(
                "resize",
                args: [.string("x"), .number(-400)]
            )
        }
        #expect(
            seen == [
                .nothingToDivide(
                    WindowID(1),
                    otherAxisDivides: true
                )
            ]
        )
    }

    @Test("A focus outside the layout is owed no sentence")
    func focusOutsideTheTiledMembersStandsDown() {
        // A native-fullscreen window keeps its slot but leaves
        // the tiled derivations (#670), so it takes part in no
        // partition — and an arrangement sentence about a
        // partition it is not in would be the wrong window told
        // the wrong thing. It was silent before #1258 because an
        // empty partition never clamps; it stays silent.
        let core = makeCore()
        let sp = space(core, windows: 2, mode: "stack")
        core.state.workspaces.focus(WindowID(1), in: sp.id)
        core.state.apply(
            .windowFullscreenChanged(
                WindowID(1),
                isFullscreen: true
            )
        )
        let seen = refusals(core) {
            for axis in ["x", "y"] {
                core.execute(
                    "resize",
                    args: [.string(axis), .number(-600)]
                )
            }
        }
        #expect(seen.isEmpty)
    }
}
