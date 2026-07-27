import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-track-swap-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// Seeds `count` windows, switches the space to track (one
/// window per track), and enables the advanced gate.
@MainActor
private func makeTrackSpace(
    _ core: KiwiCore,
    windows count: Int,
    focus: UInt32
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
    // own_track so mode-entry seeds one window per track — the
    // multi-track fixture these tests exercise. #437 flipped the
    // default to fill-then-spill, whose seed would pack them.
    core.execute(
        "track.set_new_window",
        args: [.string("own_track")]
    )
    core.execute(
        "set_mode",
        args: [.string(space.raw), .string("track")]
    )
    core.state.workspaces.focus(WindowID(focus), in: space)
    return space
}

/// Merges window `id` into the track to its left via
/// move_to_track, building multi-window tracks.
@MainActor
private func merge(
    _ core: KiwiCore,
    _ id: UInt32,
    in space: SpaceID
) {
    core.state.workspaces.focus(WindowID(id), in: space)
    #expect(
        core.execute("move_to_track", args: [.string("prev")])
            .isSuccess
    )
}

/// `track.swap` (#182): whole-track directional swap.
@Suite("track.swap (#182)", .serialized)
@MainActor
struct TrackSwapTests {
    @Test("Swaps adjacent single-window tracks")
    func swapsSingles() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 3, focus: 2)
        // [1] [2] [3] → swap next → [1] [3] [2].
        #expect(
            core.execute(
                "track.swap",
                args: [.string("next")]
            ).isSuccess
        )
        let after = core.state.workspaces[space]!
        #expect(
            after.windows == [
                WindowID(1), WindowID(3), WindowID(2),
            ]
        )
        // Focus stays on the moved window.
        #expect(after.focused == WindowID(2))
    }

    @Test("Swaps tracks of different sizes, markers travel")
    func swapsUnequalTracks() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 4, focus: 1)
        // Build [1] [2, 3] [4]: merge 3 into 2's track.
        merge(core, 3, in: space)
        core.state.workspaces.focus(WindowID(2), in: space)
        // Swap the two-window track left with [1].
        #expect(
            core.execute(
                "track.swap",
                args: [.string("prev")]
            ).isSuccess
        )
        let after = core.state.workspaces[space]!
        #expect(
            after.windows == [
                WindowID(2), WindowID(3), WindowID(1),
                WindowID(4),
            ]
        )
        // Partition is [2, 3] [1] [4]: heads carry markers.
        #expect(
            TrackLayout.counts(
                of: after.windows,
                breaks: after.trackBreaks,
                cap: 0
            ) == [2, 1, 1]
        )
    }

    @Test("Track weights ride their traveling heads")
    func weightsTravel() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 2, focus: 1)
        core.state.workspaces.withSpace(space) {
            $0.trackWeights[WindowID(1)] = 2
        }
        #expect(
            core.execute(
                "track.swap",
                args: [.string("next")]
            ).isSuccess
        )
        let after = core.state.workspaces[space]!
        #expect(after.windows == [WindowID(2), WindowID(1)])
        // The weight is keyed by the head window and moved
        // with it — track [1] keeps its double share.
        #expect(after.trackWeights[WindowID(1)] == 2)
    }

    @Test("Floating windows keep their array slots")
    func floatingKeepsSlot() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 3, focus: 1)
        // Float window 2: tiled partition is [1] [3].
        core.state.workspaces.focus(WindowID(2), in: space)
        core.execute("make_floating")
        core.state.workspaces.focus(WindowID(1), in: space)
        #expect(
            core.execute(
                "track.swap",
                args: [.string("next")]
            ).isSuccess
        )
        let after = core.state.workspaces[space]!
        // Tiled slots exchanged around the floater at index 1.
        #expect(
            after.windows == [
                WindowID(3), WindowID(2), WindowID(1),
            ]
        )
    }

    @Test("Rejected when the swap touches the folded overflow")
    func capMergeRejects() {
        let core = makeCore()
        _ = makeTrackSpace(core, windows: 4, focus: 3)
        // Four marker tracks, limit 2: the render folds tracks 3
        // and 4 into one overflow slot with no marker identity.
        // Window 3 sits in that folded slot, so a swap would
        // scramble the composition (review H1) and is refused.
        core.execute("track.set_limit", args: [.number(2)])
        let response = core.execute(
            "track.swap",
            args: [.string("next")]
        )
        #expect(!response.isSuccess)
        #expect(
            response.error?.contains("overflow") == true
        )
    }

    @Test("Normal tracks still swap while the overflow folds")
    func normalTracksSwapDespiteFold() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 4, focus: 1)
        core.execute("track.set_limit", args: [.number(2)])
        // Render: [1] [2] [3, 4 overflow]. Swapping the two
        // NORMAL tracks (1 and 2) is clean — neither is the
        // folded slot — so it succeeds even though 3 and 4 fold
        // (#198: the old blanket guard over-rejected this).
        #expect(
            core.execute(
                "track.swap",
                args: [.string("next")]
            ).isSuccess
        )
        #expect(
            core.state.workspaces[space]?.windows
                == [
                    WindowID(2), WindowID(1), WindowID(3),
                    WindowID(4),
                ]
        )
    }

    @Test("A pinned cap that folds nothing still swaps")
    func capWithoutMergeSwaps() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 2, focus: 1)
        core.execute("track.set_limit", args: [.number(2)])
        #expect(
            core.execute(
                "track.swap",
                args: [.string("next")]
            ).isSuccess
        )
        #expect(
            core.state.workspaces[space]?.windows
                == [WindowID(2), WindowID(1)]
        )
    }

    @Test("Never wraps at the edges")
    func neverWraps() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 2, focus: 1)
        _ = space
        let response = core.execute(
            "track.swap",
            args: [.string("prev")]
        )
        #expect(!response.isSuccess)
        #expect(response.error == "no prev track of focus")
    }

    @Test("A single track has no neighbor")
    func singleTrackFails() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 2, focus: 2)
        merge(core, 2, in: space)
        #expect(
            !core.execute(
                "track.swap",
                args: [.string("next")]
            ).isSuccess
        )
    }

    @Test("Compass directions are rejected (prev/next only)")
    func directionsRejected() {
        let core = makeCore()
        _ = makeTrackSpace(core, windows: 2, focus: 1)
        let response = core.execute(
            "track.swap",
            args: [.string("down")]
        )
        #expect(!response.isSuccess)
        #expect(response.error == "expected prev|next")
    }

    @Test("Non-track space and bad args fail cleanly")
    func failureShapes() {
        let core = makeCore()
        #expect(
            !core.execute(
                "track.swap",
                args: [.string("sideways")]
            ).isSuccess
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "A")
            )
        )
        // Default bsp space: refused.
        let response = core.execute(
            "track.swap",
            args: [.string("next")]
        )
        #expect(
            response.error == "track.swap needs a track space"
        )
    }
}
