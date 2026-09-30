import Foundation
import Testing

@testable import KiwiDeskCore

/// The hold outranks the incoming profile's #1230 record (#1728):
/// a window the undocked profile remembers in its own Space, but
/// which was on the gone screen, stays in the Space the same
/// change held — live, or away and remembered there.
@Suite("Held Space over the profile restore (#1728)", .serialized)
@MainActor
struct HeldSpaceRestoreTests {
    private let desk = HeldSpaceDesk()
    private let away = WindowID(22)

    /// Docked, with `solo` remembering the DELL's 10 and 11, the
    /// away 22 and the built-in's 13 in its own Spaces — the
    /// windows it saw the last time it was live.
    private func dockedWithMemory() throws -> KiwiCore {
        let core = try desk.docked()
        core.state.awayWindows[away] = AwayWindow(
            id: away,
            pid: 3,
            appName: "Away",
            appBundleID: "app.away",
            nativeSpace: 4
        )
        core.state.rememberedSpaces[away] = .departed(SpaceID(3))
        core.state.profilePartitioning.record(
            [
                Space(id: SpaceID(1), windows: desk.ids([10, 11, 22])),
                Space(id: SpaceID(2), windows: desk.ids([13])),
            ],
            as: .profile("solo")
        )
        return core
    }

    @Test("an unplug keeps a remembered window in its held Space")
    func holdKeepsRememberedWindows() throws {
        let core = try dockedWithMemory()
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(core.profiles.currentName == "solo")
        #expect(core.state.heldSpaces[SpaceID(5)]?.name == SpaceID(3))
        #expect(desk.members(core, 5) == desk.ids([10, 11]))
        #expect(core.state.rememberedSpaces[away] == .departed(SpaceID(5)))
        // The restore still runs for what was not on the DELL.
        #expect(desk.members(core, 2) == desk.ids([13]))
    }

    @Test("the held windows go home together on the replug")
    func heldWindowsGoHomeTogether() throws {
        let core = try dockedWithMemory()
        core.handle(.displaysChanged([desk.builtIn]))
        // The docked profile's record is gone (a restart, #1728's
        // second observation): only the hold can bring them home.
        core.state.profilePartitioning.forget("desk")
        core.handle(.displaysChanged([desk.builtIn, desk.dell]))
        #expect(core.profiles.currentName == "desk")
        #expect(core.state.heldSpaces.isEmpty)
        #expect(Set(desk.members(core, 3)) == Set(desk.ids([10, 11])))
        #expect(core.state.rememberedSpaces[away] == .departed(SpaceID(3)))
    }
}
