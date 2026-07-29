import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `KiwiCore.restore` — the half of snapshot replay above
/// `StateCoordinator.adopt` (which `SnapshotTests` covers):
/// layout modes come back, and in the right order (#633).
@Suite("KiwiCore restore")
@MainActor
struct RestoreTests {
    @Test("Restore reapplies a runtime layout mode")
    func modeRestored() {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace(SpaceID(1))
        // Config default is bsp; the user had switched to
        // stack at runtime before the snapshot was taken.
        let snapshot = StateSnapshot(
            windows: [],
            spaces: [
                .init(
                    space: Space(
                        id: SpaceID(1),
                        mode: .stack,
                        windows: [],
                        focused: nil
                    )
                )
            ],
            activeSpace: "1"
        )
        core.restore(snapshot)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .stack
        )
    }

    @Test("Restore never revives a mode for a dropped space")
    func modeSkipsMissingSpace() {
        let core = makeTestCore()
        let snapshot = StateSnapshot(
            windows: [],
            spaces: [
                .init(
                    space: Space(
                        id: SpaceID("old"),
                        mode: .stack,
                        windows: [],
                        focused: nil
                    )
                )
            ],
            activeSpace: nil
        )
        core.restore(snapshot)
        #expect(core.state.workspaces[SpaceID("old")] == nil)
    }

    @Test("Restore keeps the snapshot's track partition")
    func trackPartitionSurvivesModeEntry() {
        let core = makeTestCore()
        // Pin the display (#531): the track entry seed resolves
        // capacity through the visible bounds, and inheriting
        // the host's screen would make the seed — observable if
        // the reinstate ever regresses — machine-dependent.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 900)
        }
        core.state.workspaces.ensureSpace(SpaceID(1))
        for id: UInt32 in [1, 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: 100,
                        appName: "App"
                    )
                )
            )
        }
        // Entering track mode seeds a default partition; the
        // adopt that follows must overwrite it with the
        // snapshot's own breaks/weights — modes-after-adopt
        // would wipe the restored partition with the seed.
        let snapshot = StateSnapshot(
            windows: [],
            spaces: [
                .init(
                    space: Space(
                        id: SpaceID(1),
                        mode: .track,
                        windows: [WindowID(1), WindowID(2)],
                        focused: nil,
                        trackBreaks: [WindowID(1)],
                        trackWeights: [WindowID(1): 2.0]
                    )
                )
            ],
            activeSpace: "1"
        )
        core.restore(snapshot)
        let space = core.state.workspaces[SpaceID(1)]
        #expect(space?.mode == .track)
        #expect(space?.trackBreaks == Set([WindowID(1)]))
        #expect(space?.trackWeights == [WindowID(1): 2.0])
    }

    @Test("A single-track space restores without the entry seed")
    func singleTrackRestoresClean() {
        // All tracks were merged into one before capture, so
        // the record carries empty breaks/weights. The mode
        // re-application seeds a default partition on entry —
        // adopt must clear it back to the captured single
        // track, not leave the seed showing.
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 900)
        }
        core.state.workspaces.ensureSpace(SpaceID(1))
        for id: UInt32 in [1, 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: 100,
                        appName: "App"
                    )
                )
            )
        }
        let snapshot = StateSnapshot(
            windows: [],
            spaces: [
                .init(
                    space: Space(
                        id: SpaceID(1),
                        mode: .track,
                        windows: [WindowID(1), WindowID(2)],
                        focused: nil
                    )
                )
            ],
            activeSpace: "1"
        )
        core.restore(snapshot)
        let space = core.state.workspaces[SpaceID(1)]
        #expect(space?.mode == .track)
        #expect(space?.trackBreaks == [])
        #expect(space?.trackWeights == [:])
    }
}
