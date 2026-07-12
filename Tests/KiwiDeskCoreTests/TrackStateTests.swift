import Foundation
import Testing

@testable import KiwiDeskCore

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private func window(
    _ id: WindowID,
    floating: Bool = false
) -> ManagedWindow {
    ManagedWindow(
        id: id,
        pid: 1,
        appName: "Test",
        title: "w\(id)",
        frame: .zero,
        isFloating: floating
    )
}

private let allTiled: @Sendable (WindowID) -> Bool = {
    _ in true
}

@Suite("Track state maintenance (#128)")
struct TrackStateTests {
    @Test("First window seeds a single track")
    func firstWindow() {
        var space = Space(id: "1", mode: .track)
        space.insertIntoTrack(
            ids(1)[0],
            rule: .ownTrack,
            cap: 0,
            isTiled: allTiled
        )
        #expect(space.windows == ids(1))
        #expect(space.trackBreaks == [ids(1)[0]])
    }

    @Test("own_track opens a track right after the focused one")
    func ownTrackAfterFocused() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1]],
            focused: w[0],
            trackBreaks: [w[1]]
        )
        space.insertIntoTrack(
            w[2],
            rule: .ownTrack,
            cap: 0,
            isTiled: allTiled
        )
        #expect(space.windows == [w[0], w[2], w[1]])
        #expect(space.trackBreaks == [w[1], w[2]])
    }

    @Test("focused_track joins right after the focused window")
    func joinFocusedTrack() {
        let w = ids(4)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1], w[2]],
            focused: w[0],
            trackBreaks: [w[2]]
        )
        space.insertIntoTrack(
            w[3],
            rule: .focusedTrack,
            cap: 0,
            isTiled: allTiled
        )
        #expect(space.windows == [w[0], w[3], w[1], w[2]])
        #expect(space.trackBreaks == [w[2]])
    }

    @Test("own_track falls back to joining at the cap")
    func capFallsBackToJoin() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1]],
            focused: w[1],
            trackBreaks: [w[1]]
        )
        space.insertIntoTrack(
            w[2],
            rule: .ownTrack,
            cap: 2,
            isTiled: allTiled
        )
        // No new break: the third window joins the focused
        // (second) track.
        #expect(space.trackBreaks == [w[1]])
        #expect(space.windows == [w[0], w[1], w[2]])
    }

    @Test("Floating windows do not anchor the partition")
    func insertSkipsFloating() {
        let w = ids(4)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1], w[2]],
            focused: w[2],
            trackBreaks: [w[2]]
        )
        // w[1] floats: the tiled list is [w0, w2].
        space.insertIntoTrack(
            w[3],
            rule: .ownTrack,
            cap: 0,
            isTiled: { $0 != w[1] }
        )
        #expect(space.windows == [w[0], w[1], w[2], w[3]])
        #expect(space.trackBreaks == [w[2], w[3]])
    }

    @Test("Removing a head hands its break to the successor")
    func removeTransfersBreak() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: w,
            trackBreaks: [w[1]],
            trackWeights: [w[1]: 3]
        )
        space.remove(w[1])
        // w[2] inherits the break and the track weight.
        #expect(space.trackBreaks == [w[2]])
        #expect(space.trackWeights == [w[2]: 3])
    }

    @Test("Removing a lone head collapses its track")
    func removeCollapsesTrack() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: w,
            trackBreaks: [w[1], w[2]],
            trackWeights: [w[1]: 2]
        )
        space.remove(w[1])
        // w[2] already starts a track: no transfer, the middle
        // track (and its weight) is gone.
        #expect(space.trackBreaks == [w[2]])
        #expect(space.trackWeights[w[2]] == nil)
    }

    @Test("Swapping keeps track boundaries at the slot")
    func swapKeepsBoundaries() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: w,
            trackBreaks: [w[1]],
            trackWeights: [w[1]: 2]
        )
        space.swap(w[1], w[2])
        // Order [w0, w2, w1]: the boundary stays at slot 1,
        // now held by w2, with the weight following it.
        #expect(space.windows == [w[0], w[2], w[1]])
        #expect(space.trackBreaks == [w[2]])
        #expect(space.trackWeights[w[2]] == 2)
        #expect(space.trackWeights[w[1]] == nil)
    }

    @Test("Swapping an implicit index-0 head keeps its weight")
    func swapImplicitHeadWeight() {
        let w = ids(3)
        // Track [w0, w1] with w0 the implicit head (no marker)
        // carrying a weight; w2 starts a second track.
        var space = Space(
            id: "1",
            mode: .track,
            windows: w,
            trackBreaks: [w[2]],
            trackWeights: [w[0]: 3]
        )
        space.swap(w[0], w[1])
        // Order [w1, w0, w2]: the head weight stays at slot 0,
        // now held by w1 — it must not travel with w0.
        #expect(space.windows == [w[1], w[0], w[2]])
        #expect(space.trackWeights[w[1]] == 3)
        #expect(space.trackWeights[w[0]] == nil)
    }

    @Test("Removing a last-array head leaves no stale weight")
    func removeLastHeadNoStaleWeight() {
        let w = ids(3)
        // Three tracks; the last window is a head with a weight.
        var space = Space(
            id: "1",
            mode: .track,
            windows: w,
            trackBreaks: [w[1], w[2]],
            trackWeights: [w[2]: 4]
        )
        // moveWindowToTrack joins w2 (last) into w1's track:
        // its break is removed and its weight must not linger.
        _ = space.moveWindowToTrack(
            w[2],
            delta: -1,
            cap: 0,
            isTiled: allTiled
        )
        #expect(space.trackWeights[w[2]] == nil)
        // Re-opening an edge track for w2 starts it fresh (even
        // share), not resurrecting the old weight of 4.
        _ = space.moveWindowToTrack(
            w[2],
            delta: 1,
            cap: 0,
            isTiled: allTiled
        )
        #expect(space.trackWeights[w[2]] == nil)
    }

    @Test("Entering track mode seeds every window as a track")
    func modeEntrySeeds() {
        var manager = WorkspaceManager()
        manager.ensureSpace("1")
        let w = ids(3)
        for id in w {
            manager.withSpace("1") { $0.append(id) }
        }
        manager.setMode("1", .track)
        #expect(manager["1"]?.trackBreaks == Set(w))
        // Leaving clears the markers and weights.
        manager.setMode("1", .bsp)
        #expect(manager["1"]?.trackBreaks.isEmpty == true)
        #expect(manager["1"]?.trackWeights.isEmpty == true)
        // A same-mode set does not reseed (profile re-applies).
        manager.setMode("1", .track)
        manager.withSpace("1") { $0.trackBreaks = [w[0]] }
        manager.setMode("1", .track)
        #expect(manager["1"]?.trackBreaks == [w[0]])
    }
}

@Suite("Track spawn path (#128)")
struct TrackSpawnTests {
    @Test("A new window in a track space opens its own track")
    func spawnOwnTrack() {
        var state = StateCoordinator(defaultSpace: "1")
        state.workspaces.setMode("1", .track)
        let w = ids(3)
        for id in w {
            state.apply(.windowCreated(window(id)))
        }
        #expect(state.workspaces["1"]?.windows == w)
        #expect(state.workspaces["1"]?.trackBreaks == Set(w))
    }

    @Test("focused_track keeps one track growing")
    func spawnJoinsFocused() {
        var state = StateCoordinator(defaultSpace: "1")
        state.workspaces.setMode("1", .track)
        state.trackParams.newWindow = .focusedTrack
        let w = ids(3)
        for id in w {
            state.apply(.windowCreated(window(id)))
        }
        #expect(state.workspaces["1"]?.trackBreaks == [w[0]])
    }

    @Test("A per-space override caps the spawned tracks")
    func spawnHonorsOverride() {
        var state = StateCoordinator(defaultSpace: "1")
        state.workspaces.setMode("1", .track)
        var over = TrackOverride()
        // A fixed cap needs automatic off (#178); count alone is
        // the remembered magnitude, inert while auto is on.
        over.autoTracks = false
        over.count = 2
        state.trackParams.override["1"] = over
        let w = ids(3)
        for id in w {
            state.apply(.windowCreated(window(id)))
        }
        // Capped at two tracks: the third window joins the
        // focused (second) one instead of opening a third.
        let space = state.workspaces["1"]
        #expect(space?.trackBreaks == [w[0], w[1]])
        #expect(space?.windows == w)
    }

    @Test("A floating window takes the placement path")
    func floatingSkipsTrackInsert() {
        var state = StateCoordinator(defaultSpace: "1")
        state.workspaces.setMode("1", .track)
        state.apply(.windowCreated(window(ids(1)[0])))
        state.apply(
            .windowCreated(window(ids(2)[1], floating: true))
        )
        // The floating window is in the space but gained no
        // break marker.
        #expect(state.workspaces["1"]?.windows.count == 2)
        #expect(
            state.workspaces["1"]?.trackBreaks == [ids(1)[0]]
        )
    }

    @Test("Non-track spaces gain no markers")
    func nonTrackUnaffected() {
        var state = StateCoordinator(defaultSpace: "1")
        let w = ids(2)
        for id in w {
            state.apply(.windowCreated(window(id)))
        }
        #expect(
            state.workspaces["1"]?.trackBreaks.isEmpty == true
        )
    }
}
