import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Adding a Space to the profile and removing it (#1790):
/// `create_space`/`delete_space` with `profile`, Settings ▸ Spaces'
/// add button — each a write of the live profile's file at once,
/// through the live-write door.
@Suite("Temporary Space profile scope (#1790)", .serialized)
@MainActor
struct TemporarySpaceScopeTests {
    private let desk = HeldSpaceDesk()

    @Test("no layout mode is spelled like a scope")
    func scopeNeverReadsAsAMode() {
        let modes = Set(LayoutMode.allCases.map(\.rawValue))
        for scope in SpaceScope.allCases {
            #expect(!modes.contains(scope.rawValue))
        }
    }

    @Test("create_space with profile writes the Space into the file")
    func createWithProfile() throws {
        let core = try desk.docked()
        var told: [Bool] = []
        core.onLiveProfileWritten = { _, persisted in told.append(persisted) }
        core.execute(
            "pin_space_to_display",
            args: [.string("7"), .string(desk.dell.fingerprint)]
        )
        core.execute(
            "set_mode",
            args: [.string("7"), .string("monocle")]
        )
        #expect(core.isTemporary(SpaceID(7)))
        #expect(
            core.execute(
                "create_space",
                args: [.string("7"), .string("profile")]
            ).isSuccess
        )
        #expect(!core.isTemporary(SpaceID(7)))
        #expect(told == [true])
        let stored = try core.profiles.read(name: "desk")
        #expect(stored.spaces == (1...4).map { SpaceID($0) } + [SpaceID(7)])
        #expect(stored.spaceModes[SpaceID(7)] == .monocle)
        let set = try #require(
            stored.set(matching: core.liveFingerprints)
        )
        #expect(set.spaceMonitorMap[SpaceID(7)] == desk.dell.fingerprint)
        let declared = core.profiles.active?.declaredSpaces
        #expect(declared?.contains(SpaceID(7)) == true)
    }

    @Test("a Space made with profile never becomes temporary")
    func createNewWithProfile() throws {
        let core = try desk.docked()
        core.execute(
            "create_space",
            args: [.string("8"), .string("stack"), .string("profile")]
        )
        #expect(core.state.workspaces[SpaceID(8)]?.mode == .stack)
        #expect(!core.isTemporary(SpaceID(8)))
        let stored = try core.profiles.read(name: "desk")
        #expect(stored.spaceModes[SpaceID(8)] == .stack)
    }

    @Test("profile refuses a Space another source declares, naming it")
    func refusesAnotherSource() throws {
        let core = try desk.docked()
        core.initDeclaredSpaces = [SpaceID(8)]
        let reply = core.execute(
            "create_space",
            args: [.string("8"), .string("profile")]
        )
        #expect(!reply.isSuccess)
        #expect(reply.error?.contains("init.lua") == true)
        #expect(core.state.workspaces[SpaceID(8)] == nil)
    }

    @Test("profile refuses where no profile is live")
    func refusesWithoutAProfile() throws {
        let core = makeTestCore()
        let reply = core.execute(
            "create_space",
            args: [.string("8"), .string("profile")]
        )
        #expect(!reply.isSuccess)
        #expect(core.state.workspaces[SpaceID(8)] == nil)
        #expect(!core.canAddToProfile(SpaceID(8)))
    }

    @Test("delete_space with profile removes it from the file too")
    func deleteWithProfile() throws {
        let core = try desk.docked()
        #expect(
            core.execute(
                "delete_space",
                args: [.string("2"), .string("profile")]
            ).isSuccess
        )
        let stored = try core.profiles.read(name: "desk")
        #expect(!stored.declaredSpaces.contains(SpaceID(2)))
        #expect(core.state.workspaces[SpaceID(2)] == nil)
        // A plain delete leaves the file, and says so.
        let plain = core.execute("delete_space", args: [.string("1")])
        #expect(
            plain.data
                == .object([
                    "declared_in": .array([.string("profile:desk")])
                ])
        )
        let kept = try core.profiles.read(name: "desk")
        #expect(kept.spaces.contains(SpaceID(1)))
    }

    @Test("the add button's write lands in an open draft's baseline")
    func draftTakesTheAdd() throws {
        let core = try desk.docked()
        core.execute("create_space", args: [.string("7")])
        var draft = GuiConfig()
        draft.spaces = (1...4).map { SpaceID($0) }
        core.onLiveProfileWritten = { edit, _ in draft.apply(edit) }
        #expect(core.addSpaceToProfile(SpaceID(7)))
        #expect(draft.spaces.last == SpaceID(7))
        #expect(!core.addSpaceToProfile(SpaceID(7)), "no longer temporary")
    }
}
