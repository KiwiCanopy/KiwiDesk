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
        // No arrangement is live, so nothing is temporary.
        core.execute("create_space", args: [.string("8")])
        #expect(core.state.workspaces[SpaceID(8)] != nil)
        #expect(!core.isTemporary(SpaceID(8)))
        // Under a Standard: a live temporary Space, and no profile
        // file to add it to.
        core.state.workspaces.upsertDisplay(desk.builtIn)
        let composed = try #require(
            ProfileComposition.compose(
                displays: core.state.workspaces.allDisplays,
                mainID: nil
            )
        )
        core.apply(composed: composed, forceRetile: true)
        core.execute("create_space", args: [.string("scratch")])
        #expect(core.isTemporary(SpaceID("scratch")))
        #expect(!core.canAddToProfile(SpaceID("scratch")))
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

    /// The door's edit lands alike in the file and in a draft: the
    /// two applies are separate code, so they are held together.
    @Test("an added and a removed Space apply alike to file and draft")
    func editsApplyAlike() {
        let added = AddedSpace(
            after: SpaceID(1),
            mode: .monocle,
            pin: "DELL:1920x1080",
            icon: "star"
        )
        var profile = desk.profile(
            "p",
            screens: ["DELL:1920x1080"],
            spaces: [SpaceID(1), SpaceID(2)]
        )
        var draft = GuiConfig()
        draft.spaces = [SpaceID(1), SpaceID(2)]
        // Space 2 carries everything a removal must take with it.
        profile.apply(
            .addSpace(SpaceID(2), added),
            monitors: ["DELL:1920x1080"]
        )
        draft.apply(.addSpace(SpaceID(2), added))
        profile.mainSpaces = [SpaceID(2)]
        profile.fallbackSpace = SpaceID(2)
        for edit: LiveProfileEdit in [
            .addSpace(SpaceID(7), added), .removeSpace(SpaceID(2)),
        ] {
            profile.apply(edit, monitors: ["DELL:1920x1080"])
            draft.apply(edit)
        }
        #expect(profile.spaces == draft.spaces)
        #expect(profile.spaces == [SpaceID(1), SpaceID(7)])
        #expect(profile.spaceModes[SpaceID(7)] == draft.spaceModes[SpaceID(7)])
        #expect(
            profile.monitorSets.first?.spaceMonitorMap[SpaceID(7)]
                == draft.spacePins[SpaceID(7)]
        )
        #expect(
            profile.settings.spaceIcons[SpaceID(7)]
                == draft.settings.spaceIcons[SpaceID(7)]
        )
        #expect(!profile.declaredSpaces.contains(SpaceID(2)))
        #expect(profile.spaceModes[SpaceID(2)] == nil)
        #expect(draft.spaceModes[SpaceID(2)] == nil)
        #expect(profile.mainSpaces.isEmpty)
        #expect(profile.fallbackSpace == nil)
        #expect(
            profile.monitorSets.allSatisfy {
                $0.spaceMonitorMap[SpaceID(2)] == nil
            }
        )
        #expect(draft.spacePins[SpaceID(2)] == nil)
        #expect(profile.settings.spaceIcons[SpaceID(2)] == nil)
        #expect(draft.settings.spaceIcons[SpaceID(2)] == nil)
    }
}
