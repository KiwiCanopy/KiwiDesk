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

    /// The switch gives it a screen ahead of the slide's read, so
    /// the first visit slides too. The main screen is the fixture's
    /// display, so a headless host skips (#531).
    @Test(
        "a first visit to it slides",
        .enabled(if: NSScreen.main != nil)
    )
    func firstVisitSlides() throws {
        let screen = try #require(NSScreen.main)
        let display = try #require(screen.kiwiDisplayID)
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1200, height: 775)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.settings.animations.onSpaceChange = true
        core.spaceSlide.reduceMotion = { false }
        core.tiler.applier.writer = FrameWriter(
            setFrame: { _, _ in },
            setPosition: { _, _ in },
            writeEUI: { _, _ in }
        )
        core.state.workspaces.upsertDisplay(
            Display(id: display, name: "MAIN", frame: screen.frame)
        )
        let window = WindowID(1)
        core.state.apply(
            .windowCreated(ManagedWindow(id: window, pid: 1, appName: "A"))
        )
        core.state.workspaces.add(window, to: SpaceID(1))
        core.state.workspaces.assign(SpaceID(1), to: display)
        core.state.workspaces.activate(SpaceID(1))
        core.retile()
        #expect(core.state.workspaces[scratch] == nil)
        core.execute("focus_space", args: [.string(scratch.raw)])
        defer { core.spaceSlide.end() }
        #expect(core.state.workspaces.display(of: scratch) == display)
        #expect(core.spaceSlide.isPlaying)
    }
}
