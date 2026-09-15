import Foundation
import Testing

@testable import KiwiDeskCore

/// The order half of a profile restore (#1387): the record is a
/// membership, the live row the order authority — profiles.md ▸
/// "Whose arrangement is live". Split from
/// `ProfilePartitioningTests`, which holds the membership.
@Suite("A profile restore keeps the live order (#1387)", .serialized)
@MainActor
struct ProfileRestoreOrderTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-restoreorder-\(UUID().uuidString)"
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
            spaces: spaces,
            spaceModes: modes,
            settings: TilingSettings()
        )
    }

    /// Registers `ids` as live windows — the restore moves only
    /// windows that are in state, so a fixture that seeds
    /// `workspaces` alone would pass while proving nothing.
    private func live(_ core: KiwiCore, _ ids: [Int]) {
        for id in ids {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: 1,
                    appName: "App\(id)"
                )
            )
        }
    }

    private func members(
        _ core: KiwiCore,
        _ space: SpaceID
    ) -> [WindowID] {
        core.state.workspaces[space]?.windows ?? []
    }

    /// The device row of #1387 (2026-09-15): a member already in
    /// its remembered Space is left where it sits, break and all.
    @Test(
        "A window already in its remembered Space is left in place",
        arguments: [LayoutMode.track, .bsp]
    )
    func sameSpaceMemberIsLeftInPlace(mode: LayoutMode) {
        let core = makeCore()
        live(core, [1, 2, 3, 4])
        var a = profile("A", spaces: ["1"])
        a.spaceModes["1"] = mode
        var b = profile("B", spaces: ["1", "2"])
        b.spaceModes["1"] = mode
        core.apply(profile: a, forceRetile: false)
        for id in [1, 2, 3] {
            core.state.workspaces.add(WindowID(UInt32(id)), to: "1")
        }
        let breaks: Set<WindowID> =
            mode == .track ? [WindowID(1), WindowID(2), WindowID(3)] : []
        core.state.workspaces.withSpace("1") { $0.trackBreaks = breaks }

        core.apply(profile: b, forceRetile: false)
        // Opened while B is up: A has never seen it.
        core.state.workspaces.withSpace("1") {
            $0.insert(WindowID(4), placement: .last)
        }

        core.apply(profile: a, forceRetile: false)
        #expect(
            members(core, "1")
                == [1, 2, 3, 4].map { WindowID(UInt32($0)) }
        )
        if mode == .track {
            #expect(core.state.workspaces["1"]?.trackBreaks == breaks)
        }
    }

    /// The trade the skip makes, pinned: a row re-ordered under B
    /// comes back to A in B's order. The record is a membership.
    @Test("A reorder under B survives into A")
    func reorderUnderBIsKept() {
        let core = makeCore()
        live(core, [1, 2, 3])
        let a = profile("A", spaces: ["1"])
        let b = profile("B", spaces: ["1"])
        core.apply(profile: a, forceRetile: false)
        for id in [1, 2, 3] {
            core.state.workspaces.add(WindowID(UInt32(id)), to: "1")
        }
        core.apply(profile: b, forceRetile: false)
        core.state.workspaces.withSpace("1") {
            $0.windows = [WindowID(3), WindowID(1), WindowID(2)]
        }
        core.apply(profile: a, forceRetile: false)
        #expect(
            members(core, "1") == [WindowID(3), WindowID(1), WindowID(2)]
        )
    }

}
