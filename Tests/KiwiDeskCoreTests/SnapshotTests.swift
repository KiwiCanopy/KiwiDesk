import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("StateSnapshot")
struct SnapshotTests {
    private func populatedState() -> StateCoordinator {
        var state = StateCoordinator(defaultSpace: "code")
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 100,
                    appName: "Editor",
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 800,
                        height: 600
                    )
                )
            )
        )
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 200,
                    appName: "Browser",
                    frame: CGRect(
                        x: 800,
                        y: 0,
                        width: 640,
                        height: 480
                    )
                )
            )
        )
        return state
    }

    @Test("Snapshot captures windows, spaces, and focus")
    func captureContents() {
        let snapshot = populatedState().snapshot()
        #expect(snapshot.windows.count == 2)
        #expect(snapshot.spaces.count == 1)
        #expect(snapshot.activeSpace == "code")
        let space = snapshot.spaces[0]
        #expect(space.windows == [1, 2])
        #expect(space.focused == 2)
        let first = snapshot.windows.first { $0.id == 1 }
        #expect(first?.frame.width == 800)
    }

    @Test("Snapshot survives a Codable round-trip")
    func codableRoundTrip() throws {
        let original = populatedState().snapshot()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            StateSnapshot.self,
            from: data
        )
        #expect(decoded == original)
    }

    @Test("Window record exposes a typed WindowID")
    func typedWindowID() {
        let record = StateSnapshot.WindowRecord(
            id: WindowID(7),
            frame: .zero
        )
        #expect(record.windowID == WindowID(7))
    }

    @Test("Adopt restores order, membership, and focus")
    func adoptArrangement() {
        // Previous session: space 1 held [2, 1] (2 focused),
        // space "mail" held window 3.
        let snapshot = StateSnapshot(
            windows: [],
            spaces: [
                .init(
                    space: Space(
                        id: SpaceID(1),
                        mode: .bsp,
                        windows: [WindowID(2), WindowID(1)],
                        focused: WindowID(2)
                    )
                ),
                .init(
                    space: Space(
                        id: SpaceID("mail"),
                        mode: .stack,
                        windows: [WindowID(3)],
                        focused: WindowID(3)
                    )
                ),
            ],
            activeSpace: "mail"
        )
        // Fresh start discovers 1, 2, 3 in AX order: all land
        // in space 1 as [1, 2, 3]. The config load that
        // precedes a session restore declared "mail" — adopt
        // only re-files into spaces that already exist (#633).
        var state = StateCoordinator()
        state.workspaces.ensureSpace(SpaceID("mail"))
        for id: UInt32 in [1, 2, 3] {
            state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: 100,
                        appName: "App"
                    )
                )
            )
        }
        state.adopt(snapshot)
        let one = state.workspaces[SpaceID(1)]
        #expect(one?.windows == [WindowID(2), WindowID(1)])
        #expect(one?.focused == WindowID(2))
        #expect(
            state.workspaces.space(of: WindowID(3))
                == SpaceID("mail")
        )
        #expect(
            state.workspaces.activeSpace == SpaceID("mail")
        )
    }

    @Test("Adopt remembers windows that are not tracked yet")
    func adoptRemembers() {
        // Window 9 was on another native desktop at quit; it
        // is in the snapshot but not discovered at startup.
        let snapshot = StateSnapshot(
            windows: [],
            spaces: [
                .init(
                    space: Space(
                        id: SpaceID("code"),
                        mode: .bsp,
                        windows: [WindowID(9)],
                        focused: nil
                    )
                )
            ],
            activeSpace: nil
        )
        var state = StateCoordinator()
        state.workspaces.ensureSpace(SpaceID("code"))
        state.adopt(snapshot)
        #expect(
            state.workspaces[SpaceID("code")]?.windows.isEmpty
                == true
        )
        // When it reappears, it returns to its space.
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(9),
                    pid: 100,
                    appName: "App"
                )
            )
        )
        #expect(
            state.workspaces.space(of: WindowID(9))
                == SpaceID("code")
        )
    }

    @Test("Adopt preserves a track space's partition (#128)")
    func adoptTrackPartition() {
        // Previous session: a track space with three tracks
        // and a widened middle track (head weight on window 2).
        let snapshot = StateSnapshot(
            windows: [],
            spaces: [
                .init(
                    space: Space(
                        id: SpaceID(1),
                        mode: .track,
                        windows: [
                            WindowID(1), WindowID(2),
                            WindowID(3),
                        ],
                        focused: WindowID(1),
                        trackBreaks: [
                            WindowID(1), WindowID(2),
                            WindowID(3),
                        ],
                        trackWeights: [WindowID(2): 2.5]
                    )
                )
            ],
            activeSpace: "1"
        )
        // Codable round-trip: the new fields survive persistence.
        let decoded = try! JSONDecoder().decode(
            StateSnapshot.self,
            from: try! JSONEncoder().encode(snapshot)
        )
        var state = StateCoordinator()
        for id: UInt32 in [1, 2, 3] {
            state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: 100,
                        appName: "App"
                    )
                )
            )
        }
        state.adopt(decoded)
        let space = state.workspaces[SpaceID(1)]
        // Three tracks survive the remove+re-add churn — not
        // collapsed to one implicit track.
        #expect(
            space?.trackBreaks
                == Set([WindowID(1), WindowID(2), WindowID(3)])
        )
        #expect(space?.trackWeights == [WindowID(2): 2.5])
    }

    @Test("Older snapshots without track fields still decode")
    func adoptLegacySnapshot() throws {
        // A pre-#128 space record (no track_breaks/track_weights).
        let json = #"""
            {"windows":[],"activeSpace":"1",
             "capturedAt":0,
             "spaces":[{"id":"1","mode":"bsp",
                        "windows":[1],"focused":1}]}
            """#
        let snapshot = try JSONDecoder().decode(
            StateSnapshot.self,
            from: Data(json.utf8)
        )
        #expect(snapshot.spaces.first?.trackBreaks == [])
        #expect(snapshot.spaces.first?.trackWeights == [:])
    }

    @Test("Adopt never creates a space the config dropped")
    func adoptSkipsMissingSpaces() {
        // The snapshot still carries "old", but the config that
        // loaded before this restore no longer declares it —
        // resurrecting it here is what poisoned gui.json via
        // syncGuiSpacesToLive after a cross-topology boot
        // (#633).
        let snapshot = StateSnapshot(
            windows: [],
            spaces: [
                .init(
                    space: Space(
                        id: SpaceID("old"),
                        mode: .stack,
                        windows: [WindowID(1)],
                        focused: WindowID(1)
                    )
                )
            ],
            activeSpace: "old"
        )
        var state = StateCoordinator()
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 100,
                    appName: "App"
                )
            )
        )
        state.adopt(snapshot)
        #expect(state.workspaces[SpaceID("old")] == nil)
        #expect(
            state.workspaces.space(of: WindowID(1))
                == SpaceID(1)
        )
        #expect(state.workspaces.activeSpace == SpaceID(1))
    }
}
