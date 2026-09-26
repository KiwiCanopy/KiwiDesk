import Foundation
import Testing

@testable import KiwiDeskCore

/// A held Space's renumber carries every window remembered there,
/// up or not (#1669): a hidden app's window is owed to the held
/// Space, keeps it held, and comes back into it.
@Suite("Held Space memory (#1669)", .serialized)
@MainActor
struct HeldSpaceMemoryTests {
    private let desk = HeldSpaceDesk()
    private let hidden = WindowID(20)

    private var window: ManagedWindow {
        ManagedWindow(id: hidden, pid: 2, appName: "Hidden")
    }

    /// Docked, with window 20 of another app hidden from the
    /// DELL's 3 (which holds 10 and 11 as well).
    private func dockedWithHidden() throws -> KiwiCore {
        let core = try desk.docked()
        core.handle(.windowCreated(window))
        core.state.workspaces.add(hidden, to: SpaceID(3))
        core.handle(.windowHidden(hidden))
        #expect(core.state.rememberedSpaces[hidden] == .departed(SpaceID(3)))
        return core
    }

    @Test("a hold's renumber re-points a hidden window, which keeps it held")
    func holdCarriesTheHiddenWindow() throws {
        let core = try dockedWithHidden()
        let rank = core.state.departedSlots[hidden]?.rank
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(core.state.heldSpaces[SpaceID(5)]?.name == SpaceID(3))
        #expect(core.state.rememberedSpaces[hidden] == .departed(SpaceID(5)))
        // The row moved intact, so the slot rank still names it.
        #expect(rank != nil)
        #expect(core.state.departedSlots[hidden]?.rank == rank)
        for live in [10, 11] {
            core.state.workspaces.add(WindowID(UInt32(live)), to: SpaceID(1))
        }
        core.retile()
        #expect(core.state.heldSpaces[SpaceID(5)] != nil)
        core.handle(.windowCreated(window))
        #expect(core.state.workspaces.space(of: hidden) == SpaceID(5))
    }

    @Test("a reclaim's renumber re-points a hidden window too")
    func reclaimCarriesTheHiddenWindow() throws {
        let core = try dockedWithHidden()
        core.handle(.displaysChanged([desk.builtIn]))
        var solo = try core.profiles.read(name: "solo")
        solo.spaces.append(SpaceID(5))
        solo.spaceModes[SpaceID(5)] = .bsp
        core.apply(profile: solo, cause: .event)
        let held = try #require(
            core.state.heldSpaces.first { $0.value.name == SpaceID(3) }?.key
        )
        #expect(held != SpaceID(5))
        #expect(core.state.rememberedSpaces[hidden] == .departed(held))
    }

    @Test("a restored filing keeps its kind across the renumber")
    func restoredFilingKeepsItsKind() throws {
        let core = try desk.docked()
        let filed = WindowID(21)
        core.state.remember(filed, in: SpaceID(3))
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(core.state.rememberedSpaces[filed] == .restored(SpaceID(5)))
    }
}
