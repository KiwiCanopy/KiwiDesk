import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-track-nav-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

/// Boots `count` windows into the active space, switches it to
/// track mode (seeding one window per track), and focuses
/// `focus`. Returns the space id.
@MainActor
private func makeTrackSpace(
    _ core: KiwiCore,
    windows count: Int,
    focus: WindowID
) -> SpaceID {
    for id in 1...count {
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
    let space = core.state.workspaces.space(of: WindowID(1))!
    core.execute(
        "set_mode",
        args: [.string(space.raw), .string("track")]
    )
    core.state.workspaces.focus(focus, in: space)
    return space
}

/// Merges the seeded one-per-track partition into the given
/// layout: keeps breaks only on the listed heads.
@MainActor
private func setHeads(
    _ core: KiwiCore,
    space: SpaceID,
    heads: [WindowID]
) {
    core.state.workspaces.withSpace(space) {
        $0.trackBreaks = Set(heads)
    }
}

/// Track focus/swap stepping (#128): along the axis within the
/// track, across it between tracks; wrap is the #168 twin.
@Suite("Track navigation (#128)", .serialized)
@MainActor
struct TrackNavigateTests {
    @Test("Across-axis focus jumps to the adjacent track")
    func acrossFocus() {
        let core = makeCore()
        _ = makeTrackSpace(core, windows: 3, focus: WindowID(1))
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("Along-axis focus steps within the track")
    func alongFocus() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 3,
            focus: WindowID(2)
        )
        // Two tracks: [1] [2, 3].
        setHeads(core, space: space, heads: [WindowID(2)])
        #expect(
            core.execute("focus", args: [.string("down")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(3))
        // At the track's end without wrap: falls through and
        // fails (nothing below the track).
        #expect(
            !core.execute("focus", args: [.string("down")])
                .isSuccess
        )
    }

    @Test("Wrap: along the axis wraps within the track")
    func wrapWithinTrack() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 3,
            focus: WindowID(3)
        )
        setHeads(core, space: space, heads: [WindowID(2)])
        core.execute("track.set_wrap_focus", args: [.bool(true)])
        #expect(
            core.execute("focus", args: [.string("down")])
                .isSuccess
        )
        // Past the track's last (3) lands on its first (2) —
        // not on another track.
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("Wrap: across the axis wraps last to first track")
    func wrapAcrossTracks() {
        let core = makeCore()
        _ = makeTrackSpace(core, windows: 3, focus: WindowID(3))
        core.execute("track.set_wrap_focus", args: [.bool(true)])
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("swap never wraps")
    func swapNeverWraps() {
        let core = makeCore()
        _ = makeTrackSpace(core, windows: 3, focus: WindowID(3))
        core.execute("track.set_wrap_focus", args: [.bool(true)])
        #expect(
            !core.execute("swap", args: [.string("right")])
                .isSuccess
        )
    }

    @Test("Across-axis swap trades windows between tracks")
    func acrossSwap() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 2,
            focus: WindowID(1)
        )
        #expect(
            core.execute("swap", args: [.string("right")])
                .isSuccess
        )
        #expect(
            core.state.workspaces[space]?.windows
                == [WindowID(2), WindowID(1)]
        )
        // Boundaries stayed at the slots.
        #expect(
            core.state.workspaces[space]?.trackBreaks
                == Set([WindowID(1), WindowID(2)])
        )
    }
}

/// `move_to_track` (#128): joining neighbors, opening edge
/// tracks, and refusing no-ops.
@Suite("move_to_track (#128)", .serialized)
@MainActor
struct MoveToTrackTests {
    @Test("Moves the focused window into the adjacent track")
    func joinsNeighbor() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 3,
            focus: WindowID(1)
        )
        // Tracks [1] [2] [3] → move 1 right: [2] holds 1 too.
        #expect(
            core.execute(
                "move_to_track",
                args: [.string("right")]
            ).isSuccess
        )
        let after = core.state.workspaces[space]!
        #expect(
            after.windows == [
                WindowID(2), WindowID(1), WindowID(3),
            ]
        )
        #expect(
            after.trackBreaks.contains(WindowID(2))
                && after.trackBreaks.contains(WindowID(3))
        )
        #expect(!after.trackBreaks.contains(WindowID(1)))
    }

    @Test("Past the edge opens a new track")
    func opensEdgeTrack() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 3,
            focus: WindowID(2)
        )
        setHeads(core, space: space, heads: [WindowID(3)])
        // Tracks [1, 2] [3] → move 2 left: new first track.
        #expect(
            core.execute(
                "move_to_track",
                args: [.string("left")]
            ).isSuccess
        )
        let after = core.state.workspaces[space]!
        #expect(
            after.windows == [
                WindowID(2), WindowID(1), WindowID(3),
            ]
        )
        // Three tracks now: [2] [1] [3].
        #expect(
            TrackLayout.counts(
                of: after.windows,
                breaks: after.trackBreaks,
                cap: 0
            ) == [1, 1, 1]
        )
    }

    @Test("A lone edge window going outward is a no-op")
    func edgeNoOp() {
        let core = makeCore()
        _ = makeTrackSpace(core, windows: 2, focus: WindowID(2))
        #expect(
            !core.execute(
                "move_to_track",
                args: [.string("right")]
            ).isSuccess
        )
    }

    @Test("The cap blocks opening another track")
    func capBlocks() {
        let core = makeCore()
        let space = makeTrackSpace(
            core,
            windows: 2,
            focus: WindowID(2)
        )
        setHeads(core, space: space, heads: [])
        // One track [1, 2] with cap 1: no second track.
        core.execute("track.set_count", args: [.number(1)])
        #expect(
            !core.execute(
                "move_to_track",
                args: [.string("right")]
            ).isSuccess
        )
    }

    @Test("Along-axis directions are rejected")
    func alongRejected() {
        let core = makeCore()
        _ = makeTrackSpace(core, windows: 2, focus: WindowID(1))
        #expect(
            !core.execute(
                "move_to_track",
                args: [.string("down")]
            ).isSuccess
        )
    }
}
