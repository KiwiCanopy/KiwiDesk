import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-floattier-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: dir)
}

@MainActor
private func spawn(_ core: KiwiCore, count: Int) {
    for id in 1...count {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: 1,
                    appName: "A"
                )
            )
        )
    }
}

/// Floats `id` and parks its live frame at `frame`.
@MainActor
private func float(
    _ core: KiwiCore,
    _ id: WindowID,
    at frame: CGRect
) {
    core.state.windows.setFloating(id, true)
    core.state.apply(.windowMoved(id, frame))
}

/// Directional `focus` from `origin`; the landing window, or
/// nil on a dead end. Focus is re-pinned before each probe.
@MainActor
private func step(
    _ core: KiwiCore,
    space: SpaceID,
    from origin: WindowID,
    _ direction: String
) -> WindowID? {
    core.state.workspaces.focus(origin, in: space)
    guard
        core.execute("focus", args: [.string(direction)])
            .isSuccess
    else { return nil }
    return core.activeSpace?.focused
}

/// The float tier of directional `focus` (#488): floats are
/// reachable when no tiled candidate lies in the direction,
/// tiled candidates always win, `swap` never uses the tier.
@Suite("Focus float tier (#488)", .serialized)
@MainActor
struct FocusFloatTierTests {
    /// Three single-window vertical tracks; returns the tiled
    /// slot frames for float placement.
    private func makeTracks(
        _ core: KiwiCore,
        windows: Int = 3
    ) -> (space: SpaceID, slots: [WindowID: CGRect]) {
        spawn(core, count: windows)
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("track")]
        )
        return (
            SpaceID("1"),
            core.tiler.calculatedFrames(state: core.state)
        )
    }

    @Test("An edge float is reachable, and leads back in")
    func edgeFloatReachable() {
        let core = makeCore()
        let (space, _) = makeTracks(core, windows: 4)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let first = slots[WindowID(1)]!
        // Park w4 past the left edge, clear of every slot.
        float(
            core,
            WindowID(4),
            at: CGRect(
                x: first.minX - 260,
                y: first.midY - 100,
                width: 240,
                height: 200
            )
        )
        // No tiled window left of the first track: the float
        // tier reaches the parked window...
        #expect(
            step(core, space: space, from: WindowID(1), "left")
                == WindowID(4)
        )
        // ...and the excluded-anchor fallback leads back into
        // the tiles.
        #expect(
            step(core, space: space, from: WindowID(4), "right")
                == WindowID(1)
        )
    }

    @Test("A tiled candidate always beats a nearer float")
    func tiledWinsOverFloat() {
        let core = makeCore()
        let (space, _) = makeTracks(core, windows: 3)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let first = slots[WindowID(1)]!
        // Park w3 just right of w1 — nearer than w2's center.
        float(
            core,
            WindowID(3),
            at: CGRect(
                x: first.maxX + 4,
                y: first.midY - 50,
                width: 100,
                height: 100
            )
        )
        let landed = step(
            core,
            space: space,
            from: WindowID(1),
            "right"
        )
        #expect(landed == WindowID(2))
    }

    @Test("BSP: a float above a tile is reachable via up")
    func bspUpToFloat() {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_strategy",
            args: [.string("alternating")]
        )
        spawn(core, count: 3)
        let space = SpaceID("1")
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let right = slots[WindowID(2)]!
        // Park w3 above the right tile, clear of both slots.
        float(
            core,
            WindowID(3),
            at: CGRect(
                x: right.midX - 100,
                y: right.minY - 260,
                width: 200,
                height: 240
            )
        )
        // w1 (full-height left) never overlaps w2 on the x
        // axis, so no tiled candidate lies up — float tier.
        #expect(
            step(core, space: space, from: WindowID(2), "up")
                == WindowID(3)
        )
    }

    @Test("A transient overlay is never a candidate")
    func overlayNeverCandidate() {
        let core = makeCore()
        let (space, slots) = makeTracks(core, windows: 3)
        let first = slots[WindowID(1)]!
        float(
            core,
            WindowID(3),
            at: CGRect(
                x: first.minX - 260,
                y: first.midY - 100,
                width: 240,
                height: 200
            )
        )
        var overlay = core.state.windows[WindowID(3)]!
        overlay.isTransientOverlay = true
        core.state.windows.upsert(overlay)
        #expect(
            step(core, space: space, from: WindowID(1), "left")
                == nil
        )
    }

    @Test("swap never falls back to the float tier")
    func swapNeverFloatTier() {
        let core = makeCore()
        let (space, slots) = makeTracks(core, windows: 3)
        let first = slots[WindowID(1)]!
        float(
            core,
            WindowID(3),
            at: CGRect(
                x: first.minX - 260,
                y: first.midY - 100,
                width: 240,
                height: 200
            )
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        #expect(
            !core.execute("swap", args: [.string("left")])
                .isSuccess
        )
        // And the flat array is untouched — a swap-then-fail
        // regression would still trip this.
        #expect(
            core.state.workspaces[space]?.windows
                == [WindowID(1), WindowID(2), WindowID(3)]
        )
    }

    /// The live #488 probe, replayed: a float parked EXACTLY on
    /// a tiled slot has a coincident center, so no direction
    /// points at it — it stays unreachable (accepted
    /// limitation; cycle or click reaches it), while the tiles
    /// keep navigating among themselves.
    @Test("A coincident-center park stays a dead end")
    func coincidentParkDeadEnd() {
        let core = makeCore()
        let (space, _) = makeTracks(core, windows: 3)
        core.state.workspaces.focus(WindowID(1), in: space)
        core.execute("toggle_floating", args: [])
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        core.state.apply(
            .windowMoved(WindowID(1), slots[WindowID(2)]!)
        )
        // Out of the park: the fallback skips the covered
        // window (zero forward offset) to the far tile.
        #expect(
            step(core, space: space, from: WindowID(1), "right")
                == WindowID(3)
        )
        // The tiles still reach each other...
        #expect(
            step(core, space: space, from: WindowID(3), "left")
                == WindowID(2)
        )
        // ...but nothing points at the coincident park.
        #expect(
            step(core, space: space, from: WindowID(2), "left")
                == nil
        )
    }
}

/// `StateCoordinator.floatingFocusCandidates` membership rules.
@Suite("Float-tier candidates (#488)", .serialized)
@MainActor
struct FloatingFocusCandidateTests {
    @Test("Members, travelers in; overlays, fullscreen out")
    func membership() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        // 1: tiled local. 2: floating local. 3: floating local
        // transient overlay. 4: floating GLOBAL sticky homed on
        // "2" — travels into the active space. 5: floating
        // local, native fullscreen.
        for id: UInt32 in [1, 2, 3, 5] {
            var window = ManagedWindow(
                id: WindowID(id),
                pid: 1,
                appName: "A"
            )
            window.isFloating = id != 1
            window.isTransientOverlay = id == 3
            window.isFullscreen = id == 5
            core.state.windows.upsert(window)
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(4),
                pid: 1,
                appName: "A",
                isFloating: true,
                stickyScope: .global
            )
        )
        core.state.workspaces.add(WindowID(4), to: "2")
        let space = core.state.workspaces[SpaceID("1")]!
        #expect(
            core.state.floatingFocusCandidates(
                of: space,
                activeSpace: space.id
            ) == [WindowID(2), WindowID(4)]
        )
    }
}
