import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-track-cmd-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
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
            core.execute("track.set_count", args: [.number(3)])
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
        #expect(track.count == 3)
        #expect(track.newWindow == .focusedTrack)
        #expect(track.wrapFocus)
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
                "track.set_count",
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
                "track.set_count_override",
                args: [.string("2"), .number(2)]
            ).isSuccess
        )
        let over = core.tiler.settings.track.override[
            SpaceID("2")
        ]
        #expect(over?.axis == .horizontal)
        #expect(over?.count == 2)
        // The global params are untouched.
        #expect(core.tiler.settings.track.axis == .vertical)
        #expect(
            core.tiler.settings.resolvedTrack(for: "2").count
                == 2
        )
        #expect(
            core.tiler.settings.resolvedTrack(for: "1").count
                == 0
        )
    }

    @Test("set_mode accepts track and seeds the partition")
    func setModeTrack() {
        let core = makeCore()
        for id in 1...2 {
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
        let space = core.state.workspaces.space(
            of: WindowID(1)
        )!
        #expect(
            core.execute(
                "set_mode",
                args: [.string(space.raw), .string("track")]
            ).isSuccess
        )
        #expect(
            core.state.workspaces[space]?.trackBreaks
                == Set([WindowID(1), WindowID(2)])
        )
    }

    @Test("get_state surfaces the track partition")
    func getState() throws {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(7),
                    pid: 7,
                    appName: "App"
                )
            )
        )
        let space = core.state.workspaces.space(
            of: WindowID(7)
        )!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        core.state.workspaces.withSpace(space) {
            $0.trackWeights[WindowID(7)] = 2
        }
        let state = core.execute("get_state")
        guard case .object(let root)? = state.data,
            case .array(let spaces)? = root["spaces"],
            case .object(let first)? = spaces.first
        else {
            Issue.record("unexpected get_state shape")
            return
        }
        #expect(first["track_breaks"] != nil)
        #expect(first["track_weights"] != nil)
    }
}
