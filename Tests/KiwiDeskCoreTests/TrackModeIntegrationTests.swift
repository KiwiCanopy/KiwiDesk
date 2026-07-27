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

/// `track.*` mode integration (#128): `set_mode`, `get_state`,
/// the promote/demote gate, and `move_to_space` seeding.
@Suite("track.* mode integration (#128)", .serialized)
@MainActor
struct TrackModeIntegrationTests {
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
        // own_track so the seed is deterministic (one window per
        // track); the default fill-then-spill would pack by display
        // capacity (#437).
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
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
        // own_track for a deterministic one-per-track seed (#437).
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
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
        // own_track so a traveler opens its own track (the
        // fill-then-spill default would join-and-pile — #437).
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
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
        // under own_track it must open its own track, not silently
        // join the last one.
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
