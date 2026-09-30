import Foundation
import Testing

@testable import KiwiDeskCore

/// The incoming profile's #1230 record outranks the hold (#1790,
/// reversing #1728 once #1828 kept that record across a restart):
/// a window the undocked profile remembers goes to its own Space,
/// live or away, and the held Space keeps only what it never saw.
@Suite("The profile restore over a held Space (#1790)", .serialized)
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

    @Test("an unplug places a remembered window where it was")
    func memoryPlacesRememberedWindows() throws {
        let core = try dockedWithMemory()
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(core.profiles.currentName == "solo")
        #expect(desk.members(core, 1) == desk.ids([10, 11]))
        #expect(core.state.rememberedSpaces[away] == .departed(SpaceID(1)))
        #expect(desk.members(core, 2) == desk.ids([13]))
        // What `solo` never saw stays held; the emptied one retires.
        #expect(
            !core.state.heldSpaces.values.contains { $0.name == SpaceID(3) }
        )
        let held = try #require(
            core.state.heldSpaces.first { $0.value.name == SpaceID(4) }
        )
        #expect(
            desk.members(core, Int(held.key.raw) ?? 0) == desk.ids([12])
        )
    }

    @Test("the replug puts them back from the docked memory")
    func replugRestoresFromMemory() throws {
        let core = try dockedWithMemory()
        core.handle(.displaysChanged([desk.builtIn]))
        core.handle(.displaysChanged([desk.builtIn, desk.dell]))
        #expect(core.profiles.currentName == "desk")
        #expect(core.state.heldSpaces.isEmpty)
        #expect(Set(desk.members(core, 3)) == Set(desk.ids([10, 11])))
        #expect(desk.members(core, 4) == desk.ids([12]))
        #expect(core.state.rememberedSpaces[away] == .departed(SpaceID(3)))
    }
}
