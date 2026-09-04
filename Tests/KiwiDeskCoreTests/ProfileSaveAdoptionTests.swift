import Foundation
import Testing

@testable import KiwiDeskCore

/// A SAVE adopts the live slot, the way an apply does (#1230,
/// #1246). `ProfileManager.save` sets `currentName` — the saved
/// profile becomes the current one — and the partitioning's own
/// `liveProfile` has to follow it, or the profile you just saved
/// has no record of its own arrangement to come back to.
///
/// The sequence below is the device round of 2026-09-04, which
/// is where this was found: the arrangement under QA_A came back
/// as QA_B's. It starts where a real user starts — on a built-in
/// Standard, with no profile applied — which is exactly the path
/// `ProfilePartitioningTests`' fixtures skip by applying a
/// profile first.
///
/// WHICH applies count as a switch is
/// `ProfileSwitchClassificationTests`'.
@Suite("A save adopts the live slot (#1230)", .serialized)
@MainActor
struct ProfileSaveAdoptionTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-saveadopt-\(UUID().uuidString)"
                )
        )
    }

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

    /// Arrange on a Standard, `save_profile A`, `save_profile B`,
    /// `load_profile B`, rearrange, `load_profile A`. Measured on
    /// the device: A came back holding B's arrangement, because
    /// no apply had ever named A live, so A's record was never
    /// written and its restore had nothing to put back.
    @Test("A profile saved from a Standard restores its own")
    func savedProfileRestoresItsOwnArrangement() throws {
        let core = makeCore()
        live(core, [1, 2, 3])
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        core.state.workspaces.add(WindowID(3), to: "2")

        try core.persistProfile(named: "A", modes: nil)
        try core.persistProfile(named: "B", modes: nil)
        let b = try core.profiles.read(name: "B")
        let a = try core.profiles.read(name: "A")

        core.apply(profile: b, forceRetile: false)
        // The user rearranges while B is up.
        core.state.workspaces.add(WindowID(3), to: "1")

        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1") == [WindowID(1)])
        #expect(members(core, "2") == [WindowID(2), WindowID(3)])
    }

    /// The existing-profile branch adopts too, and it takes a
    /// save over a profile that is NOT the live one to see it:
    /// `profiles.save` makes its argument current whichever
    /// branch wrote it, so a Save-over-B while A is up hands the
    /// live arrangement to B — and asserting after a re-save of
    /// the live profile proves nothing, because the apply that
    /// preceded it had already adopted.
    @Test("Saving over another profile adopts the live slot")
    func saveOverAnotherProfileAdoptsTheSlot() throws {
        let core = makeCore()
        live(core, [1, 2])
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        try core.persistProfile(named: "A", modes: nil)
        try core.persistProfile(named: "B", modes: nil)
        let a = try core.profiles.read(name: "A")
        core.apply(profile: a, forceRetile: false)
        #expect(
            core.state.profilePartitioning.liveProfile == "A"
        )

        try core.persistProfile(named: "B", modes: nil)
        #expect(
            core.state.profilePartitioning.liveProfile == "B"
        )
    }
}
