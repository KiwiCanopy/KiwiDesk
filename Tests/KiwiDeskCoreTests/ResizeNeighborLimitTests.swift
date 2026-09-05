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
        // Two DISTINCT asks converging on one answer: a floor
        // is only believed corroborated (#933) — a single
        // refused ask reads as grid noise.
        for asked in [CGFloat(200), CGFloat(240)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    window,
                    size: CGSize(width: asked, height: 780)
                )
                core.tiler.boundLearner.observe(
                    window,
                    currentSize: CGSize(
                        width: min,
                        height: 780
                    ),
                    settledRead: true
                )
            }
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
        #expect(refusals == [.ownMinimum(WindowID(1), axis: "x")])
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
                    focused: WindowID(1),
                    axis: "x"
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

    @Test("A shrink bound by a zone-mate's floor cues on the mate")
    func shrinkBoundByZoneMateCuesOnMate() {
        // Three stack windows in array order [1, 2, 3]: w1 the
        // master, w2/w3 the stack zone. Focus w2; its zone-mate
        // w3 carries a learned 500 pt floor, and the zone spans
        // both on the split axis — so the mate is the window
        // that cannot shrink, and the pill goes on IT (#435),
        // not on the trier.
        let core = makeCore()
        for id: UInt32 in 1...3 {
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
        core.state.workspaces.focus(WindowID(2), in: space)
        seedMinWidth(core, window: WindowID(3), min: 500)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(-400)]
        )
        #expect(
            refusals == [
                .neighborMinimum(
                    anchor: WindowID(3),
                    focused: WindowID(2),
                    axis: "x"
                )
            ]
        )
    }

    @Test("A traveler's share write is refused, not orphaned")
    func travelerShareWriteRefused() {
        // A tiled-sticky traveler (#414 v2) homed on space 2
        // rides in space 1's track; a share write under its id
        // on space 1 could never be pruned (#308 recycled-id
        // hazard), so the write is refused.
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        for id: UInt32 in 1...2 {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(id),
                    pid: pid_t(id),
                    appName: "App\(id)"
                )
            )
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(50),
                pid: 50,
                appName: "Sticky",
                stickyScope: .global
            )
        )
        core.state.workspaces.add(WindowID(50), to: "2")
        core.execute(
            "set_mode",
            args: [.string("1"), .string("track")]
        )
        // Entering track mode seeds the 1D per-window breaks;
        // clear them so the traveler shares one track and the
        // ALONG-axis share path is actually reachable.
        core.state.workspaces.withSpace(SpaceID("1")) {
            $0.trackBreaks = []
        }
        let space = core.state.workspaces[SpaceID("1")]!
        let res = core.resizeTrackMember(
            WindowID(50),
            axis: "y",
            delta: -100,
            span: 800,
            space: space
        )
        #expect(!res.isSuccess)
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .stackWeights[WindowID(50)] == nil
        )
    }

    @Test("A grow with no neighbor names no neighbor")
    func lonelyGrowNamesNoNeighbor() {
        // One stack window: the stack zone is empty, so the
        // ratio cap still protects the region (the #383/#44
        // global floor) but there is no neighbor to blame — and
        // naming a phantom is still barred. It was WORDLESS
        // until #1258, which answers the same arrangement with
        // the fact that is true of it: the zone this axis
        // divides has one member.
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "Solo"
                )
            )
        )
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        for _ in 0..<5 {
            core.execute(
                "resize",
                args: [.string("x"), .number(600)]
            )
        }
        #expect(
            refusals.allSatisfy {
                $0
                    == .nothingToDivide(
                        WindowID(1),
                        otherAxisDivides: false
                    )
            },
            "a grow with no neighbour must never name one"
        )
        #expect(!refusals.isEmpty)
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
                    focused: WindowID(1),
                    axis: "x"
                )
            ]
        )
    }
}
