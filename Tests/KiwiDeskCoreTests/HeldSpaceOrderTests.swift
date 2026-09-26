import Foundation
import Testing

@testable import KiwiDeskCore

/// Held Spaces keep the order they left with (#1664), in number
/// and in the bar: the DELL's 3 and 4 held beside `solo`'s 1–3.
@Suite("Held Space order (#1664)", .serialized)
@MainActor
struct HeldSpaceOrderTests {
    private let desk = HeldSpaceDesk()

    /// The held Spaces in bar order, each with its origin name.
    private func heldInOrder(_ core: KiwiCore) -> [[Int]] {
        core.state.workspaces.allSpaces.compactMap { space in
            core.state.heldSpaces[space.id].map {
                [Int(space.id.raw)!, Int($0.name.raw)!]
            }
        }
    }

    @Test("an unplug that renumbers one held Space keeps the rest after it")
    func holdKeepsTheOrder() throws {
        let core = try desk.docked()
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(heldInOrder(core) == [[5, 3], [6, 4]])
    }

    @Test("a reclaim renumbers in bar order, never the dictionary's")
    func reclaimKeepsTheOrder() throws {
        let core = try desk.docked()
        core.handle(.displaysChanged([desk.builtIn]))
        var wide = try core.profiles.read(name: "solo")
        wide.spaces.append(SpaceID(5))
        wide.spaceModes[SpaceID(5)] = .bsp
        core.apply(profile: wide, cause: .event)
        #expect(heldInOrder(core) == [[7, 3], [8, 4]])
        #expect(desk.members(core, 7) == desk.ids([10, 11]))
        #expect(desk.members(core, 8) == desk.ids([12]))
    }

    @Test("a held Space whose name is free and in order keeps it")
    func freeNameInOrderIsKept() throws {
        let core = try desk.docked()
        for window in [10, 11] {
            core.state.workspaces.add(WindowID(UInt32(window)), to: SpaceID(1))
        }
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(heldInOrder(core) == [[4, 4]])
        let item = try #require(
            core.spaceBarItems(
                display: desk.builtIn.id,
                style: SpaceBarLook()
            ).first { $0.identity == .space(SpaceID(4)) }
        )
        #expect(item.held != nil)
        #expect(item.held?.originName == nil)
    }

    @Test("the walk keeps a name only above every name before it")
    func namingWalk() {
        let names = KiwiCore.orderedHeldNames(
            ["3", "9", "4", "Mail", "12"].map { SpaceID($0) },
            taken: Set(
                ["1", "2", "3", "4", "9", "12", "Mail"].map { SpaceID($0) }
            ),
            mustMove: { $0 == SpaceID("3") }
        )
        #expect(names.map(\.raw) == ["13", "14", "15", "Mail", "16"])
        let kept = KiwiCore.orderedHeldNames(
            ["7", "9"].map { SpaceID($0) },
            taken: Set(["1", "7", "9"].map { SpaceID($0) }),
            mustMove: { _ in false }
        )
        #expect(kept.map(\.raw) == ["7", "9"])
    }
}
