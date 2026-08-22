import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Resize refusal cues fire on the FIRST truncated attempt, a
/// grow is blocked by a neighbor's own minimum, and a
/// clamped-at-minimum track shrink no longer collapses the
/// space into an overflow pile (#933).
@Suite("Resize neighbor limits & first-attempt cues (#933)")
@MainActor
struct ResizeNeighborLimitTests {
    /// Pinned display (#531) and pinned gaps (#660): the span
    /// arithmetic under test divides both.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-resize-neighbor-\(UUID().uuidString)"
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

    /// Confirms a learned app-enforced floor (#677): the same
    /// ask refused with the same larger answer twice.
    private func seedMinWidth(
        _ core: KiwiCore,
        window: WindowID,
        min: CGFloat
    ) {
        for _ in 0..<2 {
            core.tiler.boundLearner.recordAsk(
                window,
                size: CGSize(width: 200, height: 780)
            )
            core.tiler.boundLearner.observe(
                window,
                currentSize: CGSize(width: min, height: 780)
            )
        }
    }

    private func makeTrackCore() -> (KiwiCore, SpaceID) {
        let core = makeCore()
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        for id: UInt32 in 1...2 {
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
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return (core, space)
    }

    @Test("The FIRST truncated shrink already cues the refusal")
    func firstShrinkAttemptCues() {
        let (core, _) = makeTrackCore()
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        // One single shrink from a balanced split straight past
        // the minimum: the clamp truncates it, and that first
        // attempt must cue — not only a second press once
        // already at the floor.
        let res = core.execute(
            "resize",
            args: [.string("x"), .number(-500)]
        )
        #expect(res.isSuccess)
        #expect(refusals == [.ownMinimum(WindowID(1))])
    }

    @Test("A clamped track shrink stays tiled — no overflow pile")
    func clampedShrinkStaysTiled() throws {
        let (core, _) = makeTrackCore()
        core.execute(
            "resize",
            args: [.string("x"), .number(-500)]
        )
        let frames = core.tiler.calculatedFrames(
            state: core.state
        )
        let first = try #require(frames[WindowID(1)])
        let second = try #require(frames[WindowID(2)])
        // A pile's signature is overlapping frames at equal
        // minX (#523); side-by-side tracks stay disjoint with
        // the shrunk one still holding ~min_window_size.
        #expect(!first.intersects(second))
        #expect(first.width >= 295)
        #expect(second.width > first.width)
    }

    @Test("A grow is blocked by the NEIGHBOR's learned minimum")
    func growBlockedByNeighborMin() throws {
        let (core, _) = makeTrackCore()
        seedMinWidth(core, window: WindowID(2), min: 500)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(600)]
        )
        #expect(
            refusals == [
                .neighborMinimum(
                    anchor: WindowID(2),
                    focused: WindowID(1)
                )
            ]
        )
        // The neighbor keeps its floor.
        let frames = core.tiler.calculatedFrames(
            state: core.state
        )
        let neighbor = try #require(frames[WindowID(2)])
        #expect(neighbor.width >= 499)
    }

    @Test("A stack ratio grow is blocked by the stack zone's minimum")
    func stackGrowBlockedByNeighborMin() {
        let core = makeCore()
        for id: UInt32 in 1...2 {
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
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        seedMinWidth(core, window: WindowID(2), min: 500)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(600)]
        )
        #expect(
            refusals == [
                .neighborMinimum(
                    anchor: WindowID(2),
                    focused: WindowID(1)
                )
            ]
        )
    }
}
