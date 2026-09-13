import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-track-cmd-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// `track.*` setters (#128): globals, per-space overrides, and
/// the get_state surface.
@Suite("track.* commands (#128)", .serialized)
@MainActor
struct TrackCommandsTests {
    @Test("Globals write the track params")
    func globals() {
        let core = makeCore()
        #expect(
            core.execute(
                "track.set_axis",
                args: [.string("horizontal")]
            ).isSuccess
        )
        #expect(
            core.execute("track.set_limit", args: [.number(3)])
                .isSuccess
        )
        #expect(
            core.execute(
                "track.set_new_window",
                args: [.string("focused_track")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "track.set_wrap_focus",
                args: [.bool(true)]
            ).isSuccess
        )
        let track = core.tiler.settings.track
        #expect(track.axis == .horizontal)
        #expect(track.limit == 3)
        #expect(track.newWindow == .focusedTrack)
        #expect(track.wrapFocus)
    }

    @Test("overflow_style + new_window_position set (#188)")
    func overflowAndPositionSetters() {
        let core = makeCore()
        // Track defaults to cascade_all (#188).
        #expect(
            core.tiler.settings.track.overflowStyle
                == .cascadeAll
        )
        #expect(
            core.execute(
                "track.set_overflow_style",
                args: [.string("cascade_overflow")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.track.overflowStyle
                == .cascadeOverflow
        )
        #expect(
            core.execute(
                "track.set_overflow_style_override",
                args: [.string("2"), .string("cascade_all")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.track.override[SpaceID("2")]?
                .overflowStyle == .cascadeAll
        )
        #expect(
            core.execute(
                "track.set_new_window_position",
                args: [.string("last")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.track.newWindowPosition == .last
        )
        // A bad value fails cleanly.
        #expect(
            !core.execute(
                "track.set_overflow_style",
                args: [.string("nonsense")]
            ).isSuccess
        )
    }

    @Test("set_limit couples the automatic flag (#178)")
    func limitCouplesAuto() {
        let core = makeCore()
        // Default is automatic (dynamic) — cap 0.
        #expect(core.tiler.settings.track.autoTracks)
        #expect(core.tiler.settings.track.trackCap == 0)
        // A positive count pins the cap and turns auto off, so
        // it takes effect without a second call.
        core.execute("track.set_limit", args: [.number(3)])
        #expect(core.tiler.settings.track.limit == 3)
        #expect(!core.tiler.settings.track.autoTracks)
        // The cap IS the limit (#1354): two normal tracks plus
        // the overflow track that catches the surplus.
        #expect(core.tiler.settings.track.trackCap == 3)
        #expect(core.tiler.settings.track.normalCap == 2)
        // 0 restores automatic, leaving the remembered count.
        core.execute("track.set_limit", args: [.number(0)])
        #expect(core.tiler.settings.track.autoTracks)
        #expect(core.tiler.settings.track.limit == 3)
        #expect(core.tiler.settings.track.trackCap == 0)
    }

    @Test("a limit below the floor is refused, naming the floor")
    func limitBelowTheFloorIsRefused() {
        // One track would be the overflow alone (#1354): the
        // setter refuses, names the floor, and writes nothing —
        // the global and the override alike; 0 stays automatic.
        let core = makeCore()
        let before = core.tiler.settings.track
        let global = core.execute(
            "track.set_limit",
            args: [.number(Double(TrackParams.minLimit - 1))]
        )
        #expect(!global.isSuccess)
        #expect(
            global.error?.contains("\(TrackParams.minLimit)") == true
        )
        #expect(core.tiler.settings.track == before)
        let override = core.execute(
            "track.set_limit_override",
            args: [.string("2"), .number(1)]
        )
        #expect(!override.isSuccess)
        #expect(core.tiler.settings.track.override[SpaceID("2")] == nil)
        #expect(
            core.execute("track.set_limit", args: [.number(0)]).isSuccess
        )
    }

    @Test("set_auto_tracks toggles the flag directly (#178)")
    func setAutoTracks() {
        let core = makeCore()
        core.execute("track.set_limit", args: [.number(4)])
        #expect(!core.tiler.settings.track.autoTracks)
        #expect(
            core.execute(
                "track.set_auto_tracks",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.tiler.settings.track.autoTracks)
        // The remembered cap survives for when auto goes off again.
        #expect(core.tiler.settings.track.limit == 4)
        #expect(core.tiler.settings.track.trackCap == 0)
        // A non-boolean is rejected.
        #expect(
            !core.execute(
                "track.set_auto_tracks",
                args: [.string("maybe")]
            ).isSuccess
        )
    }

    @Test("auto_tracks override caps only that space (#178)")
    func autoTracksOverride() {
        let core = makeCore()
        // A fixed cap in one space via the coupled count setter.
        #expect(
            core.execute(
                "track.set_limit_override",
                args: [.string("2"), .number(3)]
            ).isSuccess
        )
        let over = core.tiler.settings.track.override[
            SpaceID("2")
        ]
        #expect(over?.limit == 3)
        #expect(over?.autoTracks == false)
        // The cap is the limit, the overflow track inside it
        // (#1354).
        #expect(
            core.tiler.settings.resolvedTrack(for: "2").trackCap
                == 3
        )
        // Other spaces stay automatic.
        #expect(
            core.tiler.settings.resolvedTrack(for: "1").trackCap
                == 0
        )
    }

    @Test("Invalid values are rejected and write nothing")
    func invalidRejected() {
        let core = makeCore()
        #expect(
            !core.execute(
                "track.set_axis",
                args: [.string("diagonal")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "track.set_limit",
                args: [.number(-1)]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "track.set_new_window",
                args: [.string("nowhere")]
            ).isSuccess
        )
        #expect(core.tiler.settings.track == TrackParams())
    }

    @Test("Overrides write only that space")
    func overrides() {
        let core = makeCore()
        #expect(
            core.execute(
                "track.set_axis_override",
                args: [.string("2"), .string("horizontal")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "track.set_limit_override",
                args: [.string("2"), .number(2)]
            ).isSuccess
        )
        let over = core.tiler.settings.track.override[
            SpaceID("2")
        ]
        #expect(over?.axis == .horizontal)
        #expect(over?.limit == 2)
        // The global params are untouched.
        #expect(core.tiler.settings.track.axis == .vertical)
        #expect(
            core.tiler.settings.resolvedTrack(for: "2").limit
                == 2
        )
        #expect(
            core.tiler.settings.resolvedTrack(for: "1").limit
                == TrackParams().limit
        )
    }
}
