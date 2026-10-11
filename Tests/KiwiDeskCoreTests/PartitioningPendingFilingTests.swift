import Foundation
import Testing

@testable import KiwiDeskCore

/// A profile's record keeps the windows its Spaces hold that have
/// not arrived — the snapshot's own `pendingFilings(in:)` set
/// (#2015, owner ruling 2026-10-09): a restored filing still
/// waiting for its window, and a parked away window. Before, the
/// record kept only the up away windows, so such a window came
/// back wherever the other profile last filed it.
///
/// Each case takes A→B→A with the profiles disagreeing about the
/// window's Space, the shape `AwayProfileSpaceTests` argues is the
/// one that discriminates: B re-files it on the way out, so only
/// A's own record can carry it back.
@Suite("A record keeps not-yet-arrived windows (#2015)", .serialized)
@MainActor
struct PartitioningPendingFilingTests {
    private let w1 = WindowID(1)

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-pendingrecord-\(UUID().uuidString)"
                )
        )
    }

    private func profile(_ name: String) -> Profile {
        let spaces: [SpaceID] = ["1", "2"]
        return Profile(
            name: name,
            monitorSets: [],
            spaces: spaces,
            spaceModes: Dictionary(
                uniqueKeysWithValues: spaces.map { ($0, .bsp) }
            ),
            settings: TilingSettings()
        )
    }

    /// Files `w1` in `space` the way `kind` does, then switches
    /// A→B, re-files it under B, and switches back to A.
    private func roundTrip(
        _ core: KiwiCore,
        fileUnderA: (KiwiCore) -> Void
    ) {
        let a = profile("A")
        let b = profile("B")
        core.apply(profile: a, cause: .event)
        fileUnderA(core)
        core.apply(profile: b, cause: .event)
        _ = core.state.refileAway(of: w1, to: "1")
        #expect(core.state.rememberedSpace(of: w1) == "1")
        core.apply(profile: a, cause: .event)
    }

    @Test("a restored filing comes back to its Space")
    func restoredFilingIsKept() {
        let core = makeCore()
        roundTrip(core) { $0.state.remember(w1, in: "2") }
        #expect(core.state.rememberedSpace(of: w1) == "2")
    }

    @Test("a parked away window comes back to its Space")
    func parkedAwayWindowIsKept() {
        let core = makeCore()
        roundTrip(core) { core in
            core.state.rememberedSpaces[w1] = .departed("2")
            core.state.awayWindows[w1] = AwayWindow(
                id: w1,
                pid: 1,
                appName: "App",
                appBundleID: nil,
                nativeSpace: SkyLight.SpaceID(9),
                isUp: false
            )
        }
        #expect(core.state.rememberedSpace(of: w1) == "2")
    }

    @Test("the record and the snapshot carry the same set")
    func recordMatchesTheSnapshot() {
        let core = makeCore()
        core.apply(profile: profile("A"), cause: .event)
        core.state.remember(w1, in: "2")
        let pending = core.state.pendingFilings(in: "2")
        #expect(pending == [w1])
        let records = core.partitioningForSnapshot()?.records
        #expect(records?[.profile("A")]?["2"] == pending)
    }
}
