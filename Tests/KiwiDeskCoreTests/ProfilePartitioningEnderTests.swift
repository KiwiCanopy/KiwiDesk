import Foundation
import Testing

@testable import KiwiDeskCore

/// The three explicit enders of the per-profile partitioning
/// (#1230) — a profile deleted, a profile renamed, and the #634
/// reset. Split from `ProfilePartitioningTests` at the §2.1
/// ceiling along its own seam: that suite is the BEHAVIOUR, this
/// one is what retires a record.
///
/// Entries are deliberately not pruned on a window's
/// disappearance: an away Desktop's windows are absent from
/// `state.windows` too (#1146), so pruning on absence would make
/// a Desktop return lose its profile memory.
@Suite("Per-profile partitioning enders (#1230)", .serialized)
@MainActor
struct ProfilePartitioningEnderTests {

    @Test("A renamed profile keeps its partitioning")
    func renameFollowsThePartitioning() {
        var store = ProfilePartitioning()
        store.adoptLive("A")
        store.record(
            [Space(id: "1", windows: [WindowID(1)])],
            handingLiveTo: "B"
        )
        store.rename("A", to: "A2")
        #expect(store.remembered(for: "A") == nil)
        #expect(
            store.remembered(for: "A2")?["1"] == [WindowID(1)]
        )
    }

    @Test("A re-key moves the id in every profile's record")
    func rekeyReachesEveryProfile() {
        var store = ProfilePartitioning()
        store.adoptLive("A")
        store.record(
            [Space(id: "1", windows: [WindowID(1)])],
            handingLiveTo: "B"
        )
        store.rekey(WindowID(1), to: WindowID(77))
        #expect(
            store.remembered(for: "A")?["1"] == [WindowID(77)]
        )
    }

    @Test("Deleting a profile forgets its partitioning")
    func deleteForgets() {
        var store = ProfilePartitioning()
        store.adoptLive("A")
        store.record(
            [Space(id: "1", windows: [WindowID(1)])],
            handingLiveTo: "B"
        )
        store.forget("A")
        #expect(store.remembered(for: "A") == nil)
    }
}
