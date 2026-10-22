import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A scrolled run parks its hidden windows at the hide corner, and
/// a park snaps (#2235 ruling, 2026-10-22): on an animated pass the
/// window entering the run and the one leaving it take the instant
/// write, while the shown windows glide. `.enabled(if:)` because
/// an animated frame needs a real `NSScreen`.
@Suite(
    "Run park snaps (#2235)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunParkSnapTests {
    private static let screen = CGRect(
        x: 0,
        y: 25,
        width: 1440,
        height: 800
    )

    private func glides(_ core: KiwiCore, _ id: UInt32) -> Bool {
        core.tiler.animation.targetFrame(window: WindowID(id)) != nil
    }

    private func sent(_ core: KiwiCore, _ id: UInt32) throws -> CGRect {
        try #require(core.tiler.commandedFrame(of: WindowID(id)))
    }

    /// Six windows in one stack Space, focus on window 6: the run
    /// shows 5 and 6, and 2…4 wait parked.
    private func makeCore() -> (KiwiCore, SpaceID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-run-park-\(UUID().uuidString)"
                )
        )
        // Pinned (tests.md, #531), and the park reading answers
        // for the same screen the layout parks against.
        core.tiler.visibleBounds = { _ in Self.screen }
        core.tiler.allScreenBounds = { [Self.screen] }
        for id in 1...6 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        _ = core.execute("set_min_window_size", args: [.number(300)])
        core.state.workspaces.focus(WindowID(6), in: space)
        core.retile(animated: false)
        return (core, space)
    }

    @Test("Hidden windows rest parked at the hide corner")
    func hiddenRestParked() throws {
        let (core, space) = makeCore()
        let cover = try #require(core.tiler.runCovers[space])
        #expect(!cover.behind.isEmpty)
        for id in cover.behind.keys {
            #expect(core.tiler.looksStashed(try sent(core, id.raw)))
        }
        #expect(!core.tiler.looksStashed(try sent(core, 6)))
    }

    @Test("A scroll snaps the crossing windows and glides the rest")
    func scrollSnapsTheCrossing() throws {
        let (core, space) = makeCore()
        core.tiler.animation.isEnabled = true
        // Focus moves up to window 4: it enters the run, window 6
        // leaves it, and window 5 glides one slot.
        core.state.workspaces.focus(WindowID(4), in: space)
        core.retile(animated: true)
        let cover = try #require(core.tiler.runCovers[space])
        #expect(cover.behind[WindowID(4)] == nil)
        #expect(cover.behind[WindowID(6)] != nil)
        #expect(!glides(core, 4))
        #expect(!glides(core, 6))
        #expect(core.tiler.looksStashed(try sent(core, 6)))
        #expect(!core.tiler.looksStashed(try sent(core, 4)))
        #expect(glides(core, 5))
    }

    @Test("A park or an unpark snaps; any other frame may glide")
    func parkSnapsVerdict() {
        let slot = CGRect(x: 100, y: 100, width: 400, height: 300)
        let corner = TilingEngine.stashFrame(
            slot,
            in: Self.screen,
            corner: .bottomRight
        )
        let stashed = {
            TilingEngine.looksStashed($0, in: Self.screen)
        }
        #expect(TilingEngine.parkSnaps(from: corner, to: slot, stashed))
        #expect(TilingEngine.parkSnaps(from: slot, to: corner, stashed))
        let next = slot.offsetBy(dx: 0, dy: 310)
        #expect(!TilingEngine.parkSnaps(from: slot, to: next, stashed))
    }
}
