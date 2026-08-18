import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    // Pin the display (#531): the park corner and the geometric
    // candidates both read calculated slots.
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }
    return core
}

/// Park must not leak the parked pile into the geometric focus
/// tier (#881, owner QA): the slivers are real frames, so an
/// unwrapped cycle's dead-end fall-through geometric-hit a
/// parked window — and focusing a parked member SHOWS it, which
/// made `wrap_focus` look inert (wrap on and off both "moved
/// on"). The parked members leave the tiled tier; the wrap
/// toggle's two arms are observable again.
@Suite("Monocle park navigation (#881)", .serialized)
@MainActor
struct MonocleParkNavigationTests {
    private func makeParkCore() -> KiwiCore {
        let core = makeCore()
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: w1)!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("monocle")]
        )
        _ = core.execute(
            "monocle.set_hide_style",
            args: [.string("park")]
        )
        core.state.workspaces.focus(w3, in: space)
        return core
    }

    @Test("Wrap off: the end is a dead end, not a parked jump")
    func wrapOffDeadEndsAtTheEnd() {
        let core = makeParkCore()
        #expect(
            !core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == w3)
    }

    @Test("Wrap on: focus wraps the carousel")
    func wrapOnWraps() {
        let core = makeParkCore()
        _ = core.execute(
            "monocle.set_wrap_focus",
            args: [.bool(true)]
        )
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == w1)
    }

    @Test("Cross-axis focus finds no parked window either")
    func crossAxisStaysOffThePile() {
        // Horizontal monocle: up/down are the cross axis and
        // fall through to the geometric tier, which must not
        // reach the corner pile. Gaps ZEROED deliberately
        // (guard-prover round): with the default outer gap the
        // 1 pt sliver never overlaps the slot on x and
        // `Navigation.neighbor`'s own precondition rejects the
        // pile before the #881 filter is consulted — this test
        // must fail via the FILTER, so the slot's maxX has to
        // reach past the sliver's minX.
        let core = makeParkCore()
        _ = core.execute("set_gap_global", args: [.number(0)])
        #expect(
            !core.execute("focus", args: [.string("down")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == w3)
    }
}
