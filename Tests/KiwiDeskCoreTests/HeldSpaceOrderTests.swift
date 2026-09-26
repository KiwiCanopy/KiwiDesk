import Foundation
import Testing

@testable import KiwiDeskCore

/// Held Spaces keep the order they left with (#1664), in number
/// and in the bar.
@Suite("Held Space order (#1664)", .serialized)
@MainActor
struct HeldSpaceOrderTests {
    private let desk = HeldSpaceDesk()

    /// The held Spaces in bar order, each as "id←origin".
    private func heldInOrder(_ core: KiwiCore) -> [String] {
        core.state.workspaces.allSpaces.compactMap { space in
            core.state.heldSpaces[space.id].map {
                "\(space.id.raw)←\($0.name.raw)"
            }
        }
    }

    private func reapply(_ core: KiwiCore, declaring extra: [SpaceID])
        throws
    {
        var solo = try core.profiles.read(name: "solo")
        solo.spaces += extra
        for id in extra { solo.spaceModes[id] = .bsp }
        core.apply(profile: solo, cause: .event)
    }

    @Test("an unplug that renumbers one held Space keeps the rest after it")
    func holdKeepsTheOrder() throws {
        let core = try desk.docked()
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(heldInOrder(core) == ["5←3", "6←4"])
    }

    /// Six held Spaces, so a batch placed in the dictionary's hash
    /// order cannot pass by luck (1 in 720). A reclaim renumbers
    /// only the Space the set claims; the bar keeps the origin
    /// order even where the numbers then do not ascend.
    @Test("a reclaim keeps the bar in the order the screen had")
    func reclaimKeepsTheOrder() throws {
        let dell = (3...8).map { SpaceID($0) }
        let core = try desk.docked(dellSpaces: dell)
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(
            heldInOrder(core)
                == ["9←3", "10←4", "11←5", "12←6", "13←7", "14←8"]
        )
        try reapply(core, declaring: [SpaceID(9)])
        #expect(
            heldInOrder(core)
                == ["15←3", "10←4", "11←5", "12←6", "13←7", "14←8"]
        )
        #expect(desk.members(core, 14) == desk.ids([105]))
    }

    @Test("a named Space the walk keeps sits after a renumbered one")
    func namedSpaceFollowsTheBatch() throws {
        let core = try desk.docked(dellSpaces: [SpaceID(3), SpaceID("Mail")])
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(heldInOrder(core) == ["4←3", "Mail←Mail"])
        try reapply(core, declaring: [SpaceID(4)])
        #expect(heldInOrder(core) == ["5←3", "Mail←Mail"])
    }

    @Test("a held Space whose name is free and in order keeps it")
    func freeNameInOrderIsKept() throws {
        let core = try desk.docked()
        for window in [10, 11] {
            core.state.workspaces.add(
                WindowID(UInt32(window)),
                to: SpaceID(1)
            )
        }
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(heldInOrder(core) == ["4←4"])
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
