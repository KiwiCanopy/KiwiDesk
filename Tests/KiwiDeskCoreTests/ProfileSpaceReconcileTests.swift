import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-core-\(UUID().uuidString)"
            )
    )
}

private func profile(
    _ name: String,
    spaces: [SpaceID]
) -> Profile {
    var modes: [SpaceID: LayoutMode] = [:]
    for space in spaces { modes[space] = .bsp }
    return Profile(
        name: name,
        monitorSets: [],
        spaceModes: modes,
        settings: TilingSettings()
    )
}

/// Loading a profile makes its space set authoritative: stale
/// spaces are pruned and their windows forwarded to the first
/// space, while same-named spaces keep their windows (#bug).
@Suite("Profile-load space reconcile", .serialized)
@MainActor
struct ProfileSpaceReconcileTests {
    @Test("Undefined spaces are pruned; their windows rehome")
    func prunesAndRehomes() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.state.workspaces.add(WindowID(7), to: SpaceID("3"))
        core.apply(
            profile: profile(
                "two",
                spaces: [SpaceID("1"), SpaceID("2")]
            ),
            pruneStaleSpaces: true
        )
        // Space 3 (not in the profile) is gone; 1 and 2 survive.
        #expect(core.state.workspaces[SpaceID("3")] == nil)
        #expect(core.state.workspaces[SpaceID("1")] != nil)
        #expect(core.state.workspaces[SpaceID("2")] != nil)
        // Its window landed in the first space (order: 1).
        #expect(
            core.state.workspaces.space(of: WindowID(7))
                == SpaceID("1")
        )
    }

    @Test("A same-named space keeps its own windows")
    func sameNameKeepsWindows() {
        let core = makeCore()
        core.state.workspaces.add(WindowID(5), to: SpaceID("1"))
        core.state.workspaces.add(WindowID(9), to: SpaceID("old"))
        core.apply(
            profile: profile(
                "p",
                spaces: [SpaceID("1"), SpaceID("2")]
            ),
            pruneStaleSpaces: true
        )
        // "1" survives by name -> its window stays put; "old" is
        // pruned -> its window forwards to the first space (1).
        #expect(
            core.state.workspaces.space(of: WindowID(5))
                == SpaceID("1")
        )
        #expect(core.state.workspaces[SpaceID("old")] == nil)
        #expect(
            core.state.workspaces.space(of: WindowID(9))
                == SpaceID("1")
        )
    }

    @Test("Hardware-driven applies keep spaces, reset stale modes")
    func noPruneByDefault() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("keepme"))
        core.state.workspaces.setMode(SpaceID("keepme"), .grid)
        // Default (monitor change / native binding): no pruning —
        // an undeclared space survives, but its mode still reverts
        // to bsp (the dense reset), never keeping the stale grid.
        core.apply(profile: profile("p", spaces: [SpaceID("1")]))
        #expect(
            core.state.workspaces[SpaceID("keepme")]?.mode == .bsp
        )
    }
}
