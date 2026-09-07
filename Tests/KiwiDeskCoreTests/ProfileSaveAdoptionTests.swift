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
/// and every Settings "Apply preset" take.
///
/// The ORDER inside the door has exactly one net, and it is
/// `saveOverAnotherProfileFilesTheLiveOne`: the first test stays
/// green on a save-before-file swap, because there the just-saved
/// name and the live arrangement coincide and the record lands
/// right by accident (`guard-prover`, 2026-09-07). The two are
/// not redundant.
///
/// The last test is the other half of the single authority: the
/// apply door lands the #36 fit verdict WITH the name, read off
/// the monitor set it already matched for the pins, so no caller
/// pairs `isDirty` beside it.
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

    /// The third `profiles.save` exit. `applyStandard` composes
    /// onto live, stands the name down, then saves a NEW profile,
    /// so the door's own file is a no-op there and the outgoing
    /// profile's record is `apply(composed:)`'s.
    ///
    /// What this watches, exactly: that the compose door filed the
    /// outgoing profile AT ALL, and that the preset's saved
    /// profile is current afterwards — the clause that reds if
    /// `adoptStandard` moves below the save. It does NOT tell the
    /// pre-Standard arrangement from the post-Standard one:
    /// nothing between the compose and the save moves a window, so
    /// the two are equal here (`guard-prover`, 2026-09-07). That
    /// distinction is `ProfilePartitioningTests` ▸
    /// `standardDoesNotStealAProfilesRecord`, which rearranges
    /// while the Standard is up.
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

    /// The apply door judges the #36 fit itself, so every caller
    /// gets the verdict without spelling it — and a caller that
    /// re-applies onto hardware the profile does not describe
    /// cannot leave a stale clean flag behind.
    @Test("An apply lands the profile's own fit verdict")
    func applyLandsTheFitVerdict() throws {
        let core = makeCore()
        live(core, [1])
        let screen = Display(
            id: DisplayID(1),
            name: "A",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        core.state.workspaces.upsertDisplay(screen)
        core.state.workspaces.add(WindowID(1), to: "1")
        try core.persistProfile(named: "A", modes: nil)
        let fitting = try core.profiles.read(name: "A")

        core.profiles.markDirty()
        core.apply(profile: fitting, forceRetile: false)
        #expect(!core.profiles.isDirty)

        // A profile carrying no monitor set of its own never
        // matches the live screens (#36).
        var misfit = fitting
        misfit.name = "B"
        misfit.monitorSets = []
        core.apply(profile: misfit, forceRetile: false)
        #expect(core.profiles.currentName == "B")
        #expect(core.profiles.isDirty)
    }

    /// The #634 reset and a backup restore both end adoption, and
    /// the store keeps no name that could outlive it: the next
    /// apply is the session's FIRST, so it prunes nothing and
    /// files nothing. Until #1249 the store's own name survived
    /// `resetAdoption` — its deleted `reset()` said so — and that
    /// apply filed the post-reset arrangement under the profile
    /// the reset had just trashed.
    @Test("Resetting adoption makes the next apply the first")
    func resetAdoptionEndsTheLiveProfile() throws {
        let core = makeCore()
        live(core, [1])
        core.state.workspaces.add(WindowID(1), to: "1")
        try core.persistProfile(named: "A", modes: nil)
        let a = try core.profiles.read(name: "A")

        core.discardSavedArrangement()
        core.profiles.resetAdoption()
        core.state.workspaces.ensureSpace("restored")
        core.state.workspaces.add(WindowID(1), to: "restored")

        core.apply(profile: a, forceRetile: false)
        // Not a switch: the boot-restored space survives, and no
        // arrangement was filed under the reset profile's name.
        #expect(core.state.workspaces["restored"] != nil)
        #expect(members(core, "restored") == [WindowID(1)])
        #expect(
            core.state.profilePartitioning.remembered(for: "A")
                == nil
        )
    }
}
