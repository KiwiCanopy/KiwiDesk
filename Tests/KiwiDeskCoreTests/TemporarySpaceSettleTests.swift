import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Temporary Spaces while the arrangement moves (#1790): nothing is
/// retired mid-apply or mid-load, when "temporary" is still judged
/// against the outgoing arrangement; an arm dies with its
/// temporariness; and the live-write door and the bar's Delete act
/// on live as it has settled.
@Suite("Temporary Spaces while the arrangement moves (#1790)", .serialized)
@MainActor
struct TemporarySpaceSettleTests {
    private let desk = HeldSpaceDesk()
    private let scratch = SpaceID(9)

    /// Docked, with an EMPTY, armed, unshown temporary 9.
    private func armedAndEmpty() throws -> KiwiCore {
        let core = try desk.docked()
        core.execute("create_space", args: [.string(scratch.raw)])
        core.state.temporaryArmed.insert(scratch)
        #expect(core.isTemporary(scratch))
        return core
    }

    @Test("a switch never retires a Space the incoming profile declares")
    func incomingDeclaredArmedSurvives() throws {
        let core = try armedAndEmpty()
        try core.profiles.write(
            desk.profile(
                "wider",
                screens: [desk.builtIn.fingerprint, desk.dell.fingerprint],
                spaces: [SpaceID(1), SpaceID(2), scratch]
            )
        )
        core.execute("load_profile", args: [.string("wider")])
        core.retile()
        #expect(core.state.workspaces[scratch] != nil)
        #expect(!core.isTemporary(scratch))
        #expect(!core.state.temporaryArmed.contains(scratch))
    }

    @Test("nothing retires while the arrangement is in flight")
    func inFlightStandsDown() throws {
        let core = try armedAndEmpty()
        core.profiles.arrangementInFlight += 1
        core.retile()
        #expect(core.state.workspaces[scratch] != nil)
        core.profiles.arrangementInFlight -= 1
        core.retile()
        #expect(core.state.workspaces[scratch] == nil)
    }

    @Test("a profile delete writes the file once live has let go")
    func deleteAnnouncesAfterLive() throws {
        let core = try desk.docked()
        var liveAtWrite: Bool?
        core.onLiveProfileWritten = { _, _ in
            liveAtWrite = core.state.workspaces[SpaceID(2)] != nil
        }
        core.execute("delete_space", args: [.string("2"), .string("profile")])
        #expect(liveAtWrite == false)
    }

    @Test("an add writes the file with the Space already the profile's")
    func addAnnouncesDeclared() throws {
        let core = try desk.docked()
        core.execute("create_space", args: [.string("7")])
        var temporaryAtWrite: Bool?
        core.onLiveProfileWritten = { _, _ in
            temporaryAtWrite = core.isTemporary(SpaceID(7))
        }
        #expect(core.addSpaceToProfile(SpaceID(7)))
        #expect(temporaryAtWrite == false)
    }

    @Test("a confirmed Delete re-checks that the Space is still empty")
    func confirmedDeleteRechecks() throws {
        LocalizationManager.shared.select("en")
        let core = try desk.docked()
        core.state.workspaces.activate(SpaceID(1))
        var hooks = core.barMenuHooks
        hooks.confirmSpaceDelete = { _, confirmed in
            // A window arrives while the alert is up.
            core.state.windows.upsert(desk.window(20))
            core.state.workspaces.add(WindowID(20), to: SpaceID(2))
            confirmed()
        }
        core.barMenuHooks = hooks
        let row = core.barMenuRows(.space(SpaceID(2)))
            .first { $0.title == "Delete Space" }
        guard case .action(let perform)? = row?.kind else {
            Issue.record("no Delete row")
            return
        }
        perform()
        #expect(core.state.workspaces[SpaceID(2)] != nil)
    }

    @Test("a held and a temporary Space both retire on one pass")
    func bothRetireTogether() throws {
        let core = try desk.docked()
        core.handle(.displaysChanged([desk.builtIn]))
        let held = try #require(
            core.state.heldSpaces.first { $0.value.name == SpaceID(4) }?.key
        )
        core.execute("create_space", args: [.string("scratch")])
        core.state.temporaryArmed.insert(SpaceID("scratch"))
        core.state.workspaces.activate(SpaceID(1))
        core.state.workspaces.add(WindowID(12), to: SpaceID(1))
        core.retile()
        #expect(core.state.heldSpaces[held] == nil)
        #expect(core.state.workspaces[SpaceID("scratch")] == nil)
    }
}
