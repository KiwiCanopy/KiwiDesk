import Foundation
import Testing

@testable import KiwiDeskCore

/// What a socket request reports it changed (#1685 ▸ Ruling 4):
/// the leaves a diff names, each with where a keep would write it
/// or why none can, and an epoch a load moves.
@Suite("Change reports", .serialized)
@MainActor
struct ChangeReportTests {
    @Test("a request that does not ask carries no report")
    func unaskedCarriesNothing() throws {
        let core = try KeepFixture.core()
        let response = core.answer(
            CommandRequest(command: "border.set_width", args: [.number(9)])
        )
        #expect(response.isSuccess)
        #expect(response.changes == nil)
    }

    @Test("an own profile's leaf is kept into the profile")
    func ownLeafIsProfiles() throws {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        let response = KeepFixture.report(
            core,
            "border.set_width",
            [.number(9)]
        )
        let leaf = KeepFixture.leaf(response, "/settings/border/width")
        #expect(leaf?.owner == .profile)
        #expect(leaf?.notKeepable == nil)
        #expect(response.changes?.profile == "Odd")
    }

    @Test("a follower's look leaf is kept into the shared look")
    func followerLookLeafIsShared() throws {
        let core = try KeepFixture.core()
        let response = KeepFixture.report(
            core,
            "border.set_width",
            [.number(9)]
        )
        let leaf = KeepFixture.leaf(response, "/settings/border/width")
        #expect(leaf?.owner == .sharedLook)
    }

    @Test("a Lua-owned config keeps nothing")
    func luaOwnedKeepsNothing() throws {
        let core = try KeepFixture.core(gui: false)
        let response = KeepFixture.report(
            core,
            "border.set_width",
            [.number(9)]
        )
        let leaf = KeepFixture.leaf(response, "/settings/border/width")
        #expect(leaf?.owner == .initLua)
        #expect(leaf?.notKeepable == .luaOwned)
    }

    @Test("with no saved profile live, nothing is keepable")
    func noProfileKeepsNothing() throws {
        let core = try KeepFixture.core()
        core.profiles.resetAdoption()
        #expect(core.profiles.currentName == nil)
        let response = KeepFixture.report(
            core,
            "border.set_width",
            [.number(9)]
        )
        let leaf = KeepFixture.leaf(response, "/settings/border/width")
        #expect(leaf?.notKeepable == .noProfile)
    }

    @Test("a declared Space's layout is keepable; another is not")
    func spaceModes() throws {
        let core = try KeepFixture.core()
        let declared = KeepFixture.report(
            core,
            "set_mode",
            [.string("1"), .string("monocle")]
        )
        let one = KeepFixture.leaf(declared, "/space_modes/1")
        #expect(one?.owner == .profile)
        #expect(one?.notKeepable == nil)
        // Making a Space is no change of its layout.
        let made = KeepFixture.report(
            core,
            "set_mode",
            [.string("9"), .string("bsp")]
        )
        #expect(KeepFixture.leaf(made, "/space_modes/9") == nil)
        let other = KeepFixture.report(
            core,
            "set_mode",
            [.string("9"), .string("monocle")]
        )
        let nine = KeepFixture.leaf(other, "/space_modes/9")
        #expect(nine?.notKeepable == .temporarySpace)
    }

    @Test("an app-wide value is named, never keepable")
    func appWideIsNamed() throws {
        let core = try KeepFixture.core()
        let response = KeepFixture.report(
            core,
            "set_refusal_sound",
            [.bool(!core.appWide.refusalSound)]
        )
        let leaf = KeepFixture.leaf(response, "/app_wide/refusal/sound")
        #expect(leaf?.notKeepable == .appWide)
    }

    @Test("a watched leaf is judged stored once live matches")
    func watchedIsJudged() throws {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        let id = "/settings/border/width"
        let stored = core.tiler.settings.borderStyle.width
        _ = KeepFixture.report(core, "border.set_width", [.number(9)])
        let pending = core.answer(.reporting("version", watch: [id]))
        #expect(pending.changes?.watched.first?.stored == false)
        _ = core.execute("border.set_width", args: [.number(stored)])
        let back = core.answer(.reporting("version", watch: [id]))
        #expect(back.changes?.watched.first?.stored == true)
    }

    @Test("every wholesale replacement moves the epoch")
    func replacementsMoveTheEpoch() throws {
        let core = try KeepFixture.core()
        let before = core.settingsEpoch
        core.applyProfileScopedState(from: GuiConfig())
        #expect(core.settingsEpoch != before)
        let other = try KeepFixture.core()
        #expect(other.settingsEpoch != core.settingsEpoch)
    }

    @Test("a load moves the epoch and reports no leaves")
    func loadMovesTheEpoch() throws {
        let core = try KeepFixture.core()
        let before = KeepFixture.report(core, "version").changes?.epoch
        core.tiler.settings.borderStyle.width = 11
        let load = KeepFixture.report(
            core,
            "load_profile",
            [.string("Work")]
        )
        #expect(load.isSuccess)
        #expect(load.changes?.touched == [])
        #expect(load.changes?.epoch != before)
    }
}
