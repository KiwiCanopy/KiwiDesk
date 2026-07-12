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

    @Test("promote/demote are rejected in a track space")
    func promoteDemoteGated() {
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
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        // Would mangle the positional break markers via raw
        // swapAt — refused, and the partition is untouched.
        #expect(!core.execute("stack.promote").isSuccess)
        #expect(!core.execute("stack.demote").isSuccess)
        #expect(
            core.state.workspaces[space]?.trackBreaks
                == Set([WindowID(1), WindowID(2)])
        )
    }

    @Test("move_to_space into a track space opens its own track")
    func moveToSpaceOpensTrack() {
        let core = makeCore()
        // Space 1 (default) holds window 1; space 2 is a track
        // space holding windows 2, 3 (two tracks).
        for id in 1...3 {
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
        // Move 2 and 3 to space "2", switch it to track.
        core.state.workspaces.focus(WindowID(2), in: "1")
        core.execute("move_to_space", args: [.string("2")])
        core.state.workspaces.focus(WindowID(3), in: "1")
        core.execute("move_to_space", args: [.string("2")])
        core.execute(
            "set_mode",
            args: [.string("2"), .string("track")]
        )
        // Now move window 1 (focused in space 1) into space 2:
        // with own_track default it must open its own track,
        // not silently join the last one.
        core.state.workspaces.focus(WindowID(1), in: "1")
        #expect(
            core.execute("move_to_space", args: [.string("2")])
                .isSuccess
        )
        let space = core.state.workspaces[SpaceID("2")]!
        #expect(space.windows.contains(WindowID(1)))
        // Window 1 starts a track of its own.
        #expect(space.trackBreaks.contains(WindowID(1)))
    }
}
