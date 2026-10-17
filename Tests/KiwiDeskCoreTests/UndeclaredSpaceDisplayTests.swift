import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space a command creates by an id no declaration names takes a
/// screen at once (#1994): without one it has no Space Bar chip and
/// `activeSpace(on:)` falls back to another Space. Process A is
/// `HeldSpaceDesk`'s docked desk; Space 6 is declared nowhere.
@Suite("Undeclared Space takes a screen (#1994)", .serialized)
@MainActor
struct UndeclaredSpaceDisplayTests {
    private let desk = HeldSpaceDesk()
    private let scratch = SpaceID(6)

    private func hasChip(_ core: KiwiCore) throws -> Bool {
        let display = try #require(
            core.state.workspaces.display(of: scratch)
        )
        return core.spaceBarItems(display: display, style: SpaceBarLook())
            .contains { $0.identity == .space(scratch) }
    }

    @Test("a window moved into it gives it a chip")
    func moveTargetHasAChip() throws {
        let core = try desk.docked()
        #expect(core.state.workspaces[scratch] == nil)
        core.execute(
            "move_to_space",
            args: [.string(scratch.raw), .number(13)]
        )
        #expect(core.state.workspaces[scratch]?.windows == [WindowID(13)])
        #expect(try hasChip(core))
    }

    @Test("focusing it gives it a chip, and its screen shows it")
    func focusTargetHasAChip() throws {
        let core = try desk.docked()
        core.execute("focus_space", args: [.string(scratch.raw)])
        #expect(try hasChip(core))
        let display = try #require(
            core.state.workspaces.display(of: scratch)
        )
        #expect(core.state.workspaces.activeSpace(on: display) == scratch)
    }

    /// The net at the head of `retile`: a door with no placement of
    /// its own — `set_mode` naming a new id — still gets a chip.
    @Test("naming it in set_mode gives it a chip")
    func setModeTargetHasAChip() throws {
        let core = try desk.docked()
        core.execute("set_mode", args: [.string(scratch.raw), .string("bsp")])
        #expect(try hasChip(core))
    }

    /// Placing the new Space touches no other: a hand move of
    /// Space 3 holds until a monitor re-resolve, never a filing.
    @Test("placing it leaves a hand-moved Space where it is")
    func placementKeepsAHandMove() throws {
        let core = try desk.docked()
        core.execute(
            "move_space_to_display",
            args: [.string("3"), .string(desk.builtIn.name)]
        )
        #expect(
            core.state.workspaces.display(of: SpaceID(3)) == desk.builtIn.id
        )
        core.execute(
            "move_to_space",
            args: [.string(scratch.raw), .number(13)]
        )
        #expect(core.state.workspaces.display(of: scratch) != nil)
        #expect(
            core.state.workspaces.display(of: SpaceID(3)) == desk.builtIn.id
        )
    }

    /// The sticky gate is told where the new Space WILL lay out: a
    /// display-sticky window may not move into a Space on its own
    /// screen, and a refused move creates nothing (#1150).
    @Test("a display-sticky window is refused it on its own screen")
    func stickyGateKnowsTheLanding() throws {
        let core = makeTestCore()
        let display = DisplayID(1)
        core.state.workspaces.upsertDisplay(
            Display(
                id: display,
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        let window = WindowID(1)
        core.state.apply(
            .windowCreated(ManagedWindow(id: window, pid: 1, appName: "A"))
        )
        let origin = try #require(core.state.workspaces.space(of: window))
        core.state.workspaces.assign(origin, to: display)
        #expect(core.execute("make_display_sticky").isSuccess)
        core.execute("move_to_space", args: [.string(scratch.raw)])
        #expect(core.state.workspaces[scratch] == nil)
        #expect(core.state.workspaces.space(of: window) == origin)
    }
}
