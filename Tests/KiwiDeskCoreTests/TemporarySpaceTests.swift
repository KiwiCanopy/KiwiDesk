import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Temporary Spaces (#1790, the owner's ruling of 2026-09-30): a
/// Space a command makes is temporary, no arrangement write takes
/// it, a switch holds it while it has windows, a config load never
/// drops it, and it deletes itself once emptied. Replays the
/// held-Space desk, docked on `desk`.
@Suite("Temporary Spaces (#1790)", .serialized)
@MainActor
struct TemporarySpaceTests {
    private let desk = HeldSpaceDesk()
    private let scratch = SpaceID(9)

    private func docked() throws -> KiwiCore { try desk.docked() }

    /// Moves window 13 into a new Space 9 through the verb.
    private func movedIntoScratch(_ core: KiwiCore) {
        core.execute(
            "move_to_space",
            args: [.string(scratch.raw), .number(13)]
        )
    }

    @Test("a Space a command makes is temporary")
    func commandsMakeTemporary() throws {
        let core = try docked()
        core.execute("create_space", args: [.string("7")])
        core.execute("focus_space", args: [.string("8")])
        movedIntoScratch(core)
        for id in [SpaceID(7), SpaceID(8), scratch] {
            #expect(core.isTemporary(id))
        }
        // A declared Space is the profile's, whatever made it live.
        core.execute("focus_space", args: [.string("2")])
        #expect(!core.isTemporary(SpaceID(2)))
    }

    @Test("a declaration ends it, whichever source makes it")
    func declarationEndsIt() throws {
        let core = try docked()
        core.execute("create_space", args: [.string("7")])
        core.execute("create_space", args: [.string("8")])
        // A hand edit of the live profile that declares 8, reached
        // at the next apply — a reload.
        var profile = try core.profiles.read(name: "desk")
        profile.spaces.append(SpaceID(8))
        try core.profiles.write(profile)
        #expect(core.isTemporary(SpaceID(8)), "a write waits for the apply")
        core.loadConfig()
        #expect(!core.isTemporary(SpaceID(8)))
        // init.lua's last run named 7 (a load resets that ledger).
        core.initDeclaredSpaces = [SpaceID(7)]
        #expect(core.state.workspaces[SpaceID(7)] != nil)
        #expect(!core.isTemporary(SpaceID(7)))
        #expect(core.liveTemporarySpaces.isEmpty)
    }

    @Test("a switch keeps a number the incoming profile declares")
    func incomingDeclarationSurvives() throws {
        let core = try docked()
        movedIntoScratch(core)
        try core.profiles.write(
            desk.profile(
                "wider",
                screens: [desk.builtIn.fingerprint, desk.dell.fingerprint],
                spaces: [SpaceID(1), SpaceID(2), scratch]
            )
        )
        core.execute("load_profile", args: [.string("wider")])
        #expect(core.state.workspaces[scratch]?.windows == [WindowID(13)])
        #expect(!core.isTemporary(scratch))
    }

    @Test("a draft commit writes a Space its draft lists")
    func draftCommitWritesItsSpace() throws {
        let core = try docked()
        var config = core.guiConfigSeed()
        config.spaces.append(SpaceID(8))
        core.applyProfileScopedState(from: config)
        #expect(core.isTemporary(SpaceID(8)), "live, not yet declared")
        try core.persistProfile(
            named: "desk",
            modes: config.modes(
                for: core.capturedSpaces.map(\.id) + config.spaces
            )
        )
        let stored = try core.profiles.read(name: "desk")
        #expect(stored.spaces.contains(SpaceID(8)))
        #expect(!core.isTemporary(SpaceID(8)))
    }

    @Test("no arrangement write but save_profile takes one")
    func invisibleToArrangementWrites() throws {
        let core = try docked()
        movedIntoScratch(core)
        #expect(!core.capturedSpaces.map(\.id).contains(scratch))
        let draft = core.buildProfile(name: "desk", modes: [:])
        #expect(!draft.declaredSpaces.contains(scratch))
        core.recordLivePartitioning()
        let record = core.state.profilePartitioning.remembered(
            for: .profile("desk")
        )
        #expect(record?[scratch] == nil)
        // The whole-live snapshot writes it, and it is the
        // profile's from then on.
        #expect(
            core.execute("save_profile", args: [.string("desk")])
                .isSuccess
        )
        let saved = try core.profiles.read(name: "desk")
        #expect(saved.spaces.contains(scratch))
        #expect(!core.isTemporary(scratch))
    }

    @Test("a reload and a same-profile Load keep it; a switch holds it")
    func switchHoldsIt() throws {
        let core = try docked()
        movedIntoScratch(core)
        core.execute("create_space", args: [.string("7")])
        core.execute(
            "pin_space_to_display",
            args: [.string("7"), .string(desk.dell.fingerprint)]
        )
        core.loadConfig()
        #expect(core.isTemporary(scratch))
        #expect(core.spacePins[SpaceID(7)] == desk.dell.fingerprint)
        core.execute("load_profile", args: [.string("desk")])
        #expect(core.isTemporary(scratch))
        #expect(core.state.workspaces[scratch]?.windows == [WindowID(13)])
        core.execute("load_profile", args: [.string("solo")])
        // With windows it is held, and comes back temporary; empty,
        // it drops (#1790).
        let held = try #require(
            core.state.heldSpaces.first { $0.value.name == scratch }
        )
        #expect(held.value.isTemporary)
        #expect(core.state.workspaces[held.key]?.windows == [WindowID(13)])
        #expect(core.state.workspaces[SpaceID(7)] == nil)
        #expect(core.liveTemporarySpaces.isEmpty)
    }

    @Test("a switch to a composed Standard holds it too")
    func standardSwitchHolds() throws {
        let core = try docked()
        movedIntoScratch(core)
        let composed = try #require(
            ProfileComposition.compose(
                displays: core.state.workspaces.allDisplays,
                mainID: nil
            )
        )
        core.apply(composed: composed, forceRetile: true)
        let held = try #require(
            core.state.heldSpaces.first { $0.value.name == scratch }
        )
        #expect(held.value.isTemporary)
        #expect(core.state.workspaces.space(of: WindowID(13)) == held.key)
    }

    @Test("it deletes itself once emptied, and waits while shown")
    func autoDelete() throws {
        let core = try docked()
        // Made empty, it stays: nothing has been in it yet.
        core.execute("create_space", args: [.string("7")])
        core.retile()
        #expect(core.state.workspaces[SpaceID(7)] != nil)
        movedIntoScratch(core)
        // On Space 1's screen, so switching that screen away is
        // the one thing that stops showing it.
        core.execute(
            "pin_space_to_display",
            args: [.string(scratch.raw), .string(desk.builtIn.fingerprint)]
        )
        core.state.workspaces.activate(scratch)
        core.state.workspaces.add(WindowID(13), to: SpaceID(1))
        core.retile()
        #expect(core.state.workspaces[scratch] != nil, "shown: waits")
        core.state.workspaces.activate(SpaceID(1))
        core.retile()
        #expect(core.state.workspaces[scratch] == nil)
        #expect(core.state.workspaces[SpaceID(7)] != nil)
    }

    @Test("a hidden app's window keeps it")
    func hiddenWindowKeepsIt() throws {
        for hidden in [true, false] {
            let core = try docked()
            movedIntoScratch(core)
            // On Space 1's screen, so the retire has a sibling.
            core.execute(
                "pin_space_to_display",
                args: [
                    .string(scratch.raw), .string(desk.builtIn.fingerprint),
                ]
            )
            core.retile()
            core.state.workspaces.activate(SpaceID(1))
            core.state.workspaces.remove(WindowID(13))
            if hidden {
                core.state.rememberedSpaces[WindowID(13)] =
                    .departed(scratch)
            }
            core.retile()
            // The positive control: without the hidden window it goes.
            #expect((core.state.workspaces[scratch] != nil) == hidden)
        }
    }

    /// A Standard is live, so a profile coming in is a switch even
    /// with no partitioning record to say so.
    @Test("a switch from a Standard drops it")
    func standardToProfileDrops() throws {
        let core = try docked()
        let composed = try #require(
            ProfileComposition.compose(
                displays: core.state.workspaces.allDisplays,
                mainID: nil
            )
        )
        core.apply(composed: composed, forceRetile: true)
        // A name no Standard plans.
        let scratch = SpaceID("scratch")
        core.execute("create_space", args: [.string(scratch.raw)])
        // The Standard's own Spaces are declared by it.
        #expect(core.liveTemporarySpaces == [scratch])
        core.execute("load_profile", args: [.string("desk")])
        #expect(core.state.workspaces[scratch] == nil)
    }

    /// No partitioning record names the incoming profile: only the
    /// live Standard makes its arrival a switch.
    @Test("a Standard to a never-applied profile drops it")
    func standardToFreshProfileDrops() throws {
        let core = try docked()
        let composed = try #require(
            ProfileComposition.compose(
                displays: core.state.workspaces.allDisplays,
                mainID: nil
            )
        )
        core.apply(composed: composed, forceRetile: true)
        try core.profiles.write(
            desk.profile(
                "fresh",
                screens: [desk.builtIn.fingerprint, desk.dell.fingerprint],
                spaces: [SpaceID(1), SpaceID(2)]
            )
        )
        #expect(
            core.state.profilePartitioning.remembered(
                for: .profile("fresh")
            ) == nil
        )
        let scratch = SpaceID("scratch")
        core.execute("create_space", args: [.string(scratch.raw)])
        core.execute("load_profile", args: [.string("fresh")])
        #expect(core.state.workspaces[scratch] == nil)
    }

    @Test("a same-profile Load and a Settings Save keep its mode")
    func keepsItsMode() throws {
        let core = try docked()
        core.execute(
            "create_space",
            args: [.string("7"), .string("monocle")]
        )
        core.execute("load_profile", args: [.string("desk")])
        #expect(core.state.workspaces[SpaceID(7)]?.mode == .monocle)
        core.applyProfileScopedState(from: core.guiConfigSeed())
        #expect(core.state.workspaces[SpaceID(7)]?.mode == .monocle)
    }

    /// A settings leaf written through the door leaves what is
    /// declared to the next apply, like a plain write (#1245).
    @Test("a settings write through the door redeclares nothing")
    func settingsWriteKeepsDeclarations() throws {
        let core = try docked()
        var profile = try core.profiles.read(name: "desk")
        // `spaceModes` declares too (`declaredSpaces`).
        profile.spaces.removeAll { $0 == SpaceID(2) }
        profile.spaceModes[SpaceID(2)] = nil
        try core.profiles.write(profile)
        core.writeThroughLiveProfile(.settings { _ in })
        #expect(!core.isTemporary(SpaceID(2)))
    }

    @Test("a Settings Save keeps it, and its pin")
    func settingsSaveKeepsIt() throws {
        let core = try docked()
        core.execute("create_space", args: [.string("7")])
        core.execute(
            "pin_space_to_display",
            args: [.string("7"), .string(desk.dell.fingerprint)]
        )
        core.applyProfileScopedState(from: core.guiConfigSeed())
        #expect(core.isTemporary(SpaceID(7)))
        #expect(core.spacePins[SpaceID(7)] == desk.dell.fingerprint)
    }
}
