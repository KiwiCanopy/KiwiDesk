import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A profile WRITE files the outgoing arrangement before it
/// moves the name (#1230, #1246, #1249). `ProfileManager.save`
/// makes its argument current, so by the time it returns the
/// profile whose arrangement is on screen has no name left — and
/// filing after it records the wrong profile's windows, or none.
/// `KiwiCore.saveProfile` is the one door that orders the two.
///
/// The first test is the device round of 2026-09-04, which is
/// where this was found: the arrangement under QA_A came back as
/// QA_B's. It starts with no profile ever applied — the state
/// `ProfilePartitioningTests`' fixtures skip by applying one
/// first. `applyStandard` is the third write exit and gets its
/// own test, because that is the door the first-run Starter seed
/// and every Settings "Apply preset" take, and because its
/// ordering is the one the door cannot state for itself.
///
/// The last test is the other half of the single authority:
/// `apply(profile:)` owns the NAME and no more, so dirtiness
/// stays with the caller that can judge it.
///
/// WHICH applies count as a switch is
/// `ProfileSwitchClassificationTests`'.
@Suite("A profile write files before it renames (#1249)", .serialized)
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

    /// The existing-profile branch files too, and it takes a save
    /// over a profile that is NOT the live one to see it: a
    /// Save-over-B while A is up must leave A's own arrangement
    /// on record, and asserting after a re-save of the live
    /// profile proves nothing, because the apply that preceded it
    /// had already filed.
    @Test("Saving over another profile files the live one")
    func saveOverAnotherProfileFilesTheLiveOne() throws {
        let core = makeCore()
        live(core, [1, 2])
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        try core.persistProfile(named: "A", modes: nil)
        try core.persistProfile(named: "B", modes: nil)
        let a = try core.profiles.read(name: "A")
        core.apply(profile: a, forceRetile: false)
        // The user rearranges while A is up, then saves over B.
        core.state.workspaces.add(WindowID(2), to: "1")
        try core.persistProfile(named: "B", modes: nil)

        let filed = core.state.profilePartitioning.remembered(
            for: "A"
        )
        #expect(filed?["1"] == [WindowID(1), WindowID(2)])
        #expect(filed?["2"] == [])
        #expect(core.profiles.currentName == "B")
    }

    /// The third `profiles.save` exit, and the one whose ORDER
    /// the write door cannot state for itself. `applyStandard`
    /// composes onto live, stands the name down, then saves a NEW
    /// profile — so the door's own file is a no-op there and the
    /// outgoing profile's record is `apply(composed:)`'s, taken
    /// BEFORE the compose rearranged anything. Save first and the
    /// standard's arrangement is what lands under A's name.
    @Test("A Standard files what the outgoing profile had")
    func applyingAStandardFilesThePreStandardArrangement()
        throws
    {
        let core = makeCore()
        live(core, [1, 2])
        let screen = Display(
            id: DisplayID(1),
            name: "A",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        core.state.workspaces.upsertDisplay(screen)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        try core.persistProfile(named: "A", modes: nil)

        let name = try core.applyStandard(
            StarterSetup.standardLayout(
                displays: [screen],
                mainID: DisplayID(1)
            )
        )
        #expect(core.profiles.currentName == name)
        let filed = core.state.profilePartitioning.remembered(
            for: "A"
        )
        #expect(filed?["1"] == [WindowID(1)])
        #expect(filed?["2"] == [WindowID(2)])
    }

    /// The #634 tier-1 discard forgets saved arrangements but is
    /// NOT an adoption reset — `ProfileManager.currentName`
    /// survives it. Nilling the live slot there manufactured
    /// #1246 from a GUI button: the next write filed nothing for
    /// the profile still named current, so returning to it
    /// restored nothing.
    @Test("Discarding arrangements keeps naming the live profile")
    func discardKeepsTheLiveSlot() throws {
        let core = makeCore()
        live(core, [1, 2])
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        try core.persistProfile(named: "A", modes: nil)
        #expect(core.profiles.currentName == "A")

        core.discardSavedArrangement()
        #expect(core.profiles.currentName == "A")

        // A's arrangement is still filed by the next write, so
        // the round trip below survives the discard.
        try core.persistProfile(named: "B", modes: nil)
        let b = try core.profiles.read(name: "B")
        let a = try core.profiles.read(name: "A")
        core.apply(profile: b, forceRetile: false)
        core.state.workspaces.add(WindowID(2), to: "1")

        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1") == [WindowID(1)])
        #expect(members(core, "2") == [WindowID(2)])
    }

    /// `apply(profile:)` records the NAME and stops there. An
    /// in-effect edit re-applies a profile that is dirty for its
    /// hardware, and the re-apply did not make it match — folding
    /// a full `adopt` into the door would clear a flag the menu
    /// bar is showing for a reason no apply can see.
    @Test("An in-effect re-apply keeps the dirty flag")
    func reapplyKeepsDirty() throws {
        let core = makeCore()
        live(core, [1])
        core.state.workspaces.add(WindowID(1), to: "1")
        try core.persistProfile(named: "A", modes: nil)
        core.profiles.markDirty()

        core.reapplyIfInEffect("A")
        #expect(core.profiles.currentName == "A")
        #expect(core.profiles.isDirty)
    }
}
