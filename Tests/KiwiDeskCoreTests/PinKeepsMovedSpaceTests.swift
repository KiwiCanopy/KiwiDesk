import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A `move_space_to_display` holds through a door that changes no
/// screen (#3578): a pin of ANOTHER Space, a `create_space`, a
/// `delete_space` or a retire places only what it touched.
/// `HeldSpaceDesk`'s docked desk: Spaces 1–2 on the built-in, 3–4
/// pinned to the DELL.
@Suite("A pin keeps a hand-moved Space (#3578)", .serialized)
@MainActor
struct PinKeepsMovedSpaceTests {
    private let desk = HeldSpaceDesk()
    private let moved = SpaceID(2)

    /// Docked, with Space 2 moved to the DELL by hand.
    private func movedToDell() throws -> KiwiCore {
        let core = try desk.docked()
        core.execute(
            "move_space_to_display",
            args: [.string(moved.raw), .string(desk.dell.name)]
        )
        try #require(
            core.state.workspaces.display(of: moved) == desk.dell.id
        )
        return core
    }

    @Test("pinning another Space leaves the moved one where it is")
    func pinOfAnotherSpaceKeepsTheMove() throws {
        let core = try movedToDell()
        let pinned = core.execute(
            "pin_space_to_display",
            args: [.string("4"), .string(desk.dell.name)]
        )
        #expect(pinned.isSuccess)
        #expect(core.state.workspaces.display(of: moved) == desk.dell.id)
    }

    @Test("the pinned Space itself still lands on its screen")
    func pinPlacesThePinnedSpace() throws {
        let core = try desk.docked()
        core.execute(
            "pin_space_to_display",
            args: [.string("1"), .string(desk.dell.name)]
        )
        #expect(
            core.state.workspaces.display(of: SpaceID(1)) == desk.dell.id
        )
    }

    /// The control: a screen change re-resolves every Space and
    /// sends the moved one back. The DELL stays connected through
    /// it, so only the resolve can move Space 2, never an unplug
    /// dropping its placement.
    @Test("a screen change still re-resolves the moved Space")
    func screenChangeReresolves() throws {
        let core = try movedToDell()
        let third = Display(
            id: DisplayID(5),
            name: "THIRD",
            frame: CGRect(x: 300, y: 0, width: 100, height: 100)
        )
        core.handle(.displaysChanged([desk.builtIn, desk.dell, third]))
        core.handle(.displaysChanged([desk.builtIn, desk.dell]))
        #expect(
            core.state.workspaces.display(of: moved) == desk.builtIn.id
        )
    }

    @Test("creating a Space leaves the moved one where it is")
    func createKeepsTheMove() throws {
        let core = try movedToDell()
        #expect(core.execute("create_space", args: [.string("7")]).isSuccess)
        #expect(core.state.workspaces.display(of: SpaceID(7)) != nil)
        #expect(core.state.workspaces.display(of: moved) == desk.dell.id)
    }

    @Test("deleting a Space leaves the moved one where it is")
    func deleteKeepsTheMove() throws {
        let core = try movedToDell()
        #expect(core.execute("delete_space", args: [.string("4")]).isSuccess)
        #expect(core.state.workspaces.display(of: moved) == desk.dell.id)
    }

    @Test("an emptied temporary Space's retire leaves the move alone")
    func retireKeepsTheMove() throws {
        let core = try movedToDell()
        let fresh = SpaceID(12)
        core.execute("focus_space", args: [.string(fresh.raw)])
        try #require(core.isTemporary(fresh))
        core.execute("focus_space", args: [.string("1")])
        try #require(core.state.workspaces[fresh] == nil)
        #expect(core.state.workspaces.display(of: moved) == desk.dell.id)
    }

    /// A retire and an undeclared Space in one pass: the retire's
    /// heal does not stand in for the #1994 placement.
    @Test("a retiring pass still places an unplaced Space")
    func retirePassPlacesTheUnplaced() throws {
        let core = try desk.docked()
        let fresh = SpaceID(12)
        core.execute("focus_space", args: [.string(fresh.raw)])
        try #require(core.isTemporary(fresh))
        core.state.workspaces.activate(SpaceID(1))
        let unplaced = SpaceID(9)
        core.state.workspaces.ensureSpace(unplaced)
        try #require(core.state.workspaces.display(of: unplaced) == nil)
        core.retile()
        try #require(core.state.workspaces[fresh] == nil)
        #expect(core.state.workspaces.display(of: unplaced) != nil)
    }

    /// The area form: a move into the DELL's right area holds while
    /// another Space is pinned by an area key (#3517).
    @Test("a pin by area key leaves a move into an area alone")
    func areaPinKeepsTheAreaMove() throws {
        let core = try desk.docked()
        let split = try #require(
            ScreenSplit.whole(width: 200, height: 100)
                .splitting(0, .sideBySide)
        )
        core.state.workspaces.setAreaSplits([desk.dell.fingerprint: split])
        let dell = desk.dell.fingerprint
        core.execute(
            "move_space_to_display",
            args: [.string(moved.raw), .string("\(dell)#1")]
        )
        try #require(core.state.workspaces.placement(of: moved)?.area == 1)
        let pinned = core.execute(
            "pin_space_to_display",
            args: [.string("4"), .string("\(dell)#1")]
        )
        #expect(pinned.isSuccess)
        #expect(core.state.workspaces.placement(of: SpaceID(4))?.area == 1)
        let placement = core.state.workspaces.placement(of: moved)
        #expect(placement?.display == desk.dell.id)
        #expect(placement?.area == 1)
    }
}
