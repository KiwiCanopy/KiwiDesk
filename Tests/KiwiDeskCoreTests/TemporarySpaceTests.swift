import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Temporary Spaces (#1790, the owner's ruling of 2026-09-30): a
/// Space a command makes is temporary, no arrangement write takes
/// it, it drops on a switch and never on a config load, and it
/// deletes itself once emptied. Replays the held-Space desk, docked
/// on `desk`.
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

    @Test("a Space init.lua makes is declared, never temporary")
    func initScriptDeclares() throws {
        let core = try docked()
        _ = core.recordingTypoIssues {
            core.execute("create_space", args: [.string("7")])
        }
        #expect(core.state.workspaces[SpaceID(7)] != nil)
        #expect(!core.isTemporary(SpaceID(7)))
    }

    @Test("no arrangement write but save_profile takes one")
    func invisibleToArrangementWrites() throws {
        let core = try docked()
        movedIntoScratch(core)
        #expect(!core.capturedSpaces.map(\.id).contains(scratch))
        let draft = core.buildProfile(name: "desk", modes: [:])
        #expect(!draft.declaredSpaces.contains(scratch))
        core.recordLivePartitioning()
        let record = core.state.profilePartitioning.remembered(for: "desk")
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

    @Test("a reload and a same-profile Load keep it; a switch drops it")
    func dropsOnASwitchOnly() throws {
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
        #expect(core.state.workspaces[scratch] == nil)
        #expect(core.state.workspaces[SpaceID(7)] == nil)
        #expect(core.state.temporarySpaces.isEmpty)
        #expect(core.state.workspaces.space(of: WindowID(13)) != nil)
    }

    @Test("a switch to a composed Standard drops it too")
    func standardSwitchDrops() throws {
        let core = try docked()
        movedIntoScratch(core)
        let composed = try #require(
            ProfileComposition.compose(
                displays: core.state.workspaces.allDisplays,
                mainID: nil
            )
        )
        core.apply(composed: composed, forceRetile: true)
        #expect(core.state.workspaces[scratch] == nil)
        #expect(core.state.workspaces.space(of: WindowID(13)) != nil)
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
        let core = try docked()
        movedIntoScratch(core)
        core.state.workspaces.activate(SpaceID(1))
        core.state.workspaces.remove(WindowID(13))
        core.state.rememberedSpaces[WindowID(13)] = .departed(scratch)
        core.retile()
        #expect(core.state.workspaces[scratch] != nil)
    }
}
