import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
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
            pruneStaleSpaces: true,
            forceRetile: true
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
            pruneStaleSpaces: true,
            forceRetile: true
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

    @Test("A profile declaring no spaces prunes nothing")
    func emptyProfileKeepsSpaces() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        // Degenerate: no declared spaces -> no fallback -> the
        // guard skips pruning rather than wiping every space.
        core.apply(
            profile: profile("empty", spaces: []),
            pruneStaleSpaces: true,
            forceRetile: true
        )
        #expect(core.state.workspaces[SpaceID("1")] != nil)
        #expect(core.state.workspaces[SpaceID("2")] != nil)
    }

    @Test("Pruning the active space moves active to a survivor")
    func activeSpaceReassignedOnPrune() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.activate(SpaceID("stale"))
        // The active space isn't in the profile -> pruned; active
        // must land on a surviving space, never nil or the removed
        // one.
        core.apply(
            profile: profile("p", spaces: [SpaceID("1")]),
            pruneStaleSpaces: true,
            forceRetile: true
        )
        #expect(core.state.workspaces[SpaceID("stale")] == nil)
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
    }

    // MARK: - Stored-order rehome (#75)

    @Test("Rehome uses profile's stored space order")
    func rehomeUsesStoredOrder() {
        // Verify that the reconcile fallback is the first space
        // in the profile's *stored* order, not the sorted order.
        // With stored order ["2", "1"], the sorted order would
        // give "1" first — ensure "2" is used instead.
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.state.workspaces.add(WindowID(42), to: SpaceID("old"))
        let p = Profile(
            name: "p",
            monitorSets: [],
            spaces: [SpaceID("2"), SpaceID("1")],
            spaceModes: [
                SpaceID("1"): .bsp,
                SpaceID("2"): .bsp,
            ],
            settings: TilingSettings()
        )
        core.apply(
            profile: p,
            pruneStaleSpaces: true,
            forceRetile: true
        )
        // "old" pruned; its window rehomes to "2" (first in
        // stored order), not "1" (first in numeric order).
        #expect(
            core.state.workspaces.space(of: WindowID(42))
                == SpaceID("2")
        )
    }

    @Test("Explicit fallback space wins over stored order")
    func explicitFallbackBeatsOrder() {
        let core = makeCore()
        core.state.workspaces.add(
            WindowID(42),
            to: SpaceID("old")
        )
        let p = Profile(
            name: "p",
            monitorSets: [],
            spaces: [SpaceID("1"), SpaceID("2")],
            fallbackSpace: SpaceID("2"),
            spaceModes: [
                SpaceID("1"): .bsp,
                SpaceID("2"): .bsp,
            ],
            settings: TilingSettings()
        )
        core.apply(
            profile: p,
            pruneStaleSpaces: true,
            forceRetile: true
        )
        // "old" pruned; its window rehomes to the designated
        // fallback "2", not the order's first entry "1" (#68).
        #expect(
            core.state.workspaces.space(of: WindowID(42))
                == SpaceID("2")
        )
        #expect(core.fallbackSpace == SpaceID("2"))
    }

    @Test("Dangling fallback falls back to the stored order")
    func danglingFallbackUsesOrder() {
        let core = makeCore()
        core.state.workspaces.add(
            WindowID(42),
            to: SpaceID("old")
        )
        let p = Profile(
            name: "p",
            monitorSets: [],
            spaces: [SpaceID("2"), SpaceID("1")],
            fallbackSpace: SpaceID("gone"),
            spaceModes: [
                SpaceID("1"): .bsp,
                SpaceID("2"): .bsp,
            ],
            settings: TilingSettings()
        )
        core.apply(
            profile: p,
            pruneStaleSpaces: true,
            forceRetile: true
        )
        // The explicit target isn't a survivor — the stored
        // order's first entry decides, as before #68.
        #expect(
            core.state.workspaces.space(of: WindowID(42))
                == SpaceID("2")
        )
        // The dangling reference must not be adopted live.
        #expect(core.fallbackSpace == nil)
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
        core.apply(
            profile: profile("p", spaces: [SpaceID("1")]),
            forceRetile: false
        )
        #expect(
            core.state.workspaces[SpaceID("keepme")]?.mode == .bsp
        )
    }
}
