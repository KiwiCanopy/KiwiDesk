import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-track-gate-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

/// Seeds `count` windows and switches their space to track,
/// returning the space id.
@MainActor
private func makeTrackSpace(
    _ core: KiwiCore,
    windows count: Int
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
    return space
}

/// The advanced-track gate (#181): default track is the 1D
/// columns/rows layout; `set_track_advanced` unlocks the 2D
/// authoring surfaces. Setters accept-and-store; the clamp
/// applies at resolution; actions reject with a pointer.
@Suite("Advanced-track gate (#181)", .serialized)
@MainActor
struct TrackAdvancedGateTests {
    @Test("Defaults off; the command toggles and validates")
    func toggle() {
        let core = makeCore()
        #expect(!core.isTrackAdvanced)
        #expect(
            core.execute(
                "set_track_advanced",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.isTrackAdvanced)
        #expect(
            core.execute(
                "set_track_advanced",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.isTrackAdvanced)
        #expect(
            !core.execute(
                "set_track_advanced",
                args: [.string("maybe")]
            ).isSuccess
        )
    }

    @Test("Setters store while off; resolution clamps to 1D")
    func settersStoreClampAtResolution() {
        let core = makeCore()
        core.execute("track.set_count", args: [.number(2)])
        core.execute(
            "track.set_new_window",
            args: [.string("focused_track")]
        )
        // Stored values keep what the setters wrote…
        #expect(!core.tiler.settings.track.autoTracks)
        #expect(core.tiler.settings.track.count == 2)
        #expect(
            core.tiler.settings.track.newWindow
                == .focusedTrack
        )
        // …but the effective view is clamped back to 1D.
        let off = core.effectiveTrack(for: "1")
        #expect(off.autoTracks)
        #expect(off.trackCap == 0)
        #expect(off.newWindow == .ownTrack)
        // Per-space overrides are clamped too (clamp runs
        // after resolution, covering both in one stroke).
        core.execute(
            "track.set_count_override",
            args: [.string("2"), .number(3)]
        )
        #expect(core.effectiveTrack(for: "2").trackCap == 0)
        // The flag restores the stored values untouched.
        core.execute(
            "set_track_advanced",
            args: [.bool(true)]
        )
        let on = core.effectiveTrack(for: "1")
        #expect(!on.autoTracks)
        #expect(on.trackCap == 2)
        #expect(on.newWindow == .focusedTrack)
        #expect(core.effectiveTrack(for: "2").trackCap == 3)
    }

    @Test("move_to_track rejects with the pointer while off")
    func moveToTrackRejects() {
        let core = makeCore()
        let space = makeTrackSpace(core, windows: 2)
        core.state.workspaces.focus(WindowID(1), in: space)
        let off = core.execute(
            "move_to_track",
            args: [.string("right")]
        )
        #expect(!off.isSuccess)
        #expect(off.error == KiwiCore.trackAdvancedHint)
        // The partition is untouched by the rejected action.
        #expect(
            core.state.workspaces[space]?.trackBreaks
                == Set([WindowID(1), WindowID(2)])
        )
        core.execute(
            "set_track_advanced",
            args: [.bool(true)]
        )
        #expect(
            core.execute(
                "move_to_track",
                args: [.string("right")]
            ).isSuccess
        )
    }

    @Test("New windows open their own track while off")
    func newWindowClampedToOwnTrack() {
        let core = makeCore()
        core.execute(
            "track.set_new_window",
            args: [.string("focused_track")]
        )
        let space = makeTrackSpace(core, windows: 2)
        core.state.workspaces.focus(WindowID(1), in: space)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(9),
                    pid: 9,
                    appName: "App9"
                )
            )
        )
        // focused_track would have joined window 1's track; the
        // clamp forces a fresh track instead.
        #expect(
            core.state.workspaces[space]?.trackBreaks
                .contains(WindowID(9)) == true
        )
    }

    @Test("Toggling off grandfathers built 2D tracks")
    func toggleOffKeepsState() {
        let core = makeCore()
        core.execute(
            "set_track_advanced",
            args: [.bool(true)]
        )
        let space = makeTrackSpace(core, windows: 3)
        core.state.workspaces.focus(WindowID(1), in: space)
        #expect(
            core.execute(
                "move_to_track",
                args: [.string("right")]
            ).isSuccess
        )
        let breaks = core.state.workspaces[space]?.trackBreaks
        // Window 1 joined window 2's track: a real 2D state.
        #expect(breaks?.count == 2)
        core.execute(
            "set_track_advanced",
            args: [.bool(false)]
        )
        // Gate authoring, not state: markers stay untouched.
        #expect(
            core.state.workspaces[space]?.trackBreaks == breaks
        )
    }

    @Test("Cap merge is a read-time view: OFF expands it")
    func capMergeExpandsWhenOff() {
        let core = makeCore()
        core.execute(
            "set_track_advanced",
            args: [.bool(true)]
        )
        core.execute("track.set_count", args: [.number(2)])
        let space = makeTrackSpace(core, windows: 4)
        _ = space
        // ON: four marker tracks merge into the cap of 2.
        let params = core.effectiveTrack(for: space)
        let tiled = (1...4).map { WindowID(UInt32($0)) }
        let merged = TrackLayout.counts(
            of: tiled,
            breaks: Set(tiled),
            cap: params.trackCap
        )
        #expect(merged == [1, 3])
        // OFF: the cap disappears from the resolved view and
        // the marker partition shows through — a visible
        // relayout, correct per the model (documented in
        // design-decisions).
        core.execute(
            "set_track_advanced",
            args: [.bool(false)]
        )
        let expanded = TrackLayout.counts(
            of: tiled,
            breaks: Set(tiled),
            cap: core.effectiveTrack(for: space).trackCap
        )
        #expect(expanded == [1, 1, 1, 1])
    }

    @Test("Gated bindings match only exact catalog bodies")
    func gatedBindingShape() {
        #expect(
            TrackAdvancedBindings.isGated(
                "KiwiDesk.move_to_track(\"left\")"
            )
        )
        // A custom row merely containing the call registers
        // normally — its other actions must keep firing.
        #expect(
            !TrackAdvancedBindings.isGated(
                "KiwiDesk.move_to_track(\"left\") "
                    + "KiwiDesk.focus(\"left\")"
            )
        )
    }
}
