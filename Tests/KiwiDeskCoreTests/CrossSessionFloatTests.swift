import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// A hand float crosses a restart (#1864 ruling, 2026-10-09): the
/// boot pairing re-keys it onto the reopened window, and a late
/// arrival takes it with its frame through the owed-arrival store.
@Suite("Cross-session hand floats (#1864)", .serialized)
@MainActor
struct CrossSessionFloatTests: CrossSessionFixture {
    /// The freeze's desk with its one record floated by hand.
    private func floated() -> StateSnapshot {
        var snapshot = previous([(F.hidden, "app.zen", "Zen Browser")])
        snapshot.windows[0].floating = true
        return snapshot
    }

    @Test(
        "a window paired at boot floats again",
        .enabled(if: NSScreen.main != nil)
    )
    func bootPairFloats() throws {
        let core = try #require(boot([window(10, "app.zen", "Zen Browser")]))
        leave(floated(), in: core)
        arrange(core)
        #expect(space(core, 10) == F.hidden)
        #expect(core.state.userFloated.contains(WindowID(10)))
    }

    /// Two windows of one app pair only by title, at the pass.
    @Test(
        "a window paired by the title pass floats again, at its frame",
        .enabled(if: NSScreen.main != nil)
    )
    func titlePassFloats() throws {
        let core = try #require(
            boot([
                window(20, "com.ide", "Preview"),
                window(21, "com.ide", "IDE"),
            ])
        )
        var desk = previous([
            (F.shown, "com.ide", "IDE"),
            (F.hidden, "com.ide", "Preview"),
        ])
        desk.windows[1].floating = true
        leave(desk, in: core)
        arrange(core)
        #expect(!core.state.userFloated.contains(WindowID(20)))
        core.crossSessionSettlePass()
        #expect(space(core, 20) == F.hidden)
        #expect(core.state.userFloated.contains(WindowID(20)))
        #expect(!core.state.userFloated.contains(WindowID(21)))
        #expect(core.tiler.stashOriginal(WindowID(20)) == Self.recorded)
    }

    @Test(
        "a late arrival floats again, at its frame",
        .enabled(if: NSScreen.main != nil)
    )
    func lateArrivalFloats() throws {
        let core = try #require(boot([]))
        leave(floated(), in: core)
        arrange(core)
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        #expect(space(core, 30) == F.hidden)
        #expect(core.state.userFloated.contains(WindowID(30)))
        #expect(core.tiler.stashOriginal(WindowID(30)) == Self.recorded)
    }
}
