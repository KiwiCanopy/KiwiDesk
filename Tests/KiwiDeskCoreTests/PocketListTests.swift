import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket as an ordered list (#2678): `pocket` puts away the
/// out window used last before it takes any out, and takes out the
/// window put in last. Marking several windows is #2678's Several
/// windows mode, so these fixtures mark through the state.
@Suite("Pocket list", .serialized)
@MainActor
struct PocketListTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private let three = WindowID(3)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-pocket-\(UUID().uuidString)")
        )
        for raw: UInt32 in [3, 2, 1] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "App\(raw)",
                        title: "Window \(raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        return core
    }

    /// `one` and `two` marked, out, `two` focused last; the focus on
    /// `three`, a plain tiled window.
    private func markTwo(_ core: KiwiCore) {
        core.state.markPocketWindow(one)
        core.state.markPocketWindow(two)
        core.state.apply(.windowFocused(three))
    }

    @Test("from a plain focus, the out window used last goes back")
    func putsAwayFirst() {
        let core = makeCore()
        markTwo(core)
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketPhase(of: two) == .pocketed)
        #expect(core.state.pocketPhase(of: one) == .out)
        core.execute("pocket")
        #expect(core.state.pocketedWindows == [two, one])
    }

    @Test("a focus report on an out window makes it the one used last")
    func focusReportRanks() {
        let core = makeCore()
        markTwo(core)
        core.handle(.windowFocused(one))
        core.state.apply(.windowFocused(three))
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(core.state.pocketPhase(of: two) == .out)
    }

    @Test("the focused out window goes back whatever the order")
    func focusedWins() {
        let core = makeCore()
        markTwo(core)
        core.state.apply(.windowFocused(one))
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(core.state.pocketPhase(of: two) == .out)
    }

    @Test("with every window in, the one put in last comes out")
    func takesOutLastIn() {
        let core = makeCore()
        markTwo(core)
        core.execute("pocket")
        core.execute("pocket")
        #expect(core.state.pocketTakeOutNext == one)
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(core.state.pocketPhase(of: two) == .pocketed)
    }

    @Test("a take-out counts as a focus")
    func takeOutRanks() {
        let core = makeCore()
        // `two` marked first, so `one`'s mark is the later focus.
        core.state.markPocketWindow(two)
        core.state.markPocketWindow(one)
        core.state.pocketWindow(two)
        #expect(core.takePocketOut(two))
        core.state.apply(.windowFocused(three))
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: two) == .pocketed)
        #expect(core.state.pocketPhase(of: one) == .out)
    }

    @Test("a window put back becomes the one put in last")
    func putBackReorders() {
        let core = makeCore()
        markTwo(core)
        core.execute("pocket")
        core.execute("pocket")
        // Out by another door: `two`, put in first.
        #expect(core.takePocketOut(two))
        core.state.apply(.windowFocused(three))
        core.execute("pocket")
        #expect(core.state.pocketedWindows == [one, two])
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: two) == .out)
        #expect(core.state.pocketPhase(of: one) == .pocketed)
    }

    @Test("a second mark is still refused in One window")
    func secondMarkRefused() {
        let core = makeCore()
        core.state.apply(.windowFocused(one))
        core.execute("toggle_pocket_window")
        core.state.apply(.windowFocused(two))
        #expect(!core.execute("toggle_pocket_window").isSuccess)
        #expect(core.state.pocket.map(\.window) == [one])
    }

    @Test("a quit files every pocketed window into the active Space")
    func quitReleasesAll() {
        let core = makeCore()
        markTwo(core)
        core.execute("pocket")
        core.execute("pocket")
        core.releasePocketForQuit()
        #expect(core.state.pocket.isEmpty)
        let active = core.state.workspaces.activeSpace
        #expect(core.state.workspaces.space(of: one) == active)
        #expect(core.state.workspaces.space(of: two) == active)
    }

    @Test("minimizing one window empties its slot alone")
    func minimizeEmptiesOne() {
        let core = makeCore()
        markTwo(core)
        core.state.apply(.windowDestroyed(one, wasMinimized: true))
        #expect(core.state.pocket.map(\.window) == [two])
    }
}
