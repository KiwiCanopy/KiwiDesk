import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket through the one bar pass (#2678 review 10, 11, 4, 1):
/// `updateBars()` asks the shelf's plan for the pocket's slot and
/// mounts the pocket on that shelf; the pocket stands on every
/// display; a drag stands it under One window; a list open on a
/// risen handle holds it out.
@Suite(
    "Pocket shelf wiring",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketShelfWiringTests {
    private let one = WindowID(1)

    private func makeCore() throws -> (KiwiCore, DisplayID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-wiring-\(UUID().uuidString)")
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: one,
                    pid: 900_001,
                    appName: "App1",
                    title: "Window 1",
                    frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                )
            )
        )
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        // The Space Bar on the pocket's edge, always shown.
        core.tiler.settings.spaceBarStyle.edge = .bottom
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.tiler.settings.kiwishelf.pocketEdge = .bottom
        return (core, id)
    }

    @Test("a bar pass pins the slot and mounts the pocket on its shelf")
    func barPassMountsThePocket() throws {
        let (core, display) = try makeCore()
        core.execute("pocket.set_capacity", args: [.string("several")])
        core.updateBars()
        let slot = try #require(core.pocketPlate.slots[display])
        let overlay = try #require(
            core.shelves.overlayForTesting(display, edge: .bottom)
        )
        let mount = try #require(overlay.pocket.mount)
        #expect(mount.slot == slot)
        #expect(mount.view === core.pocketPlate.sectionMount(on: display))
        // The pocket's panel is the shelf's for the peek's look.
        let panel = try #require(overlay.pocket.panel)
        #expect(core.shelves.shelf(drawnIn: panel) != nil)
        // A level above the shelf and the drag's ghost (#2776).
        #expect(panel.level == BarPanel.aboveLevel)
    }

    @Test("under One window a drag stands the pocket inside the strip")
    func dragStandsThePocket() throws {
        let (core, display) = try makeCore()
        // A margin, so the inside frame's own outer of 0 is told apart.
        core.tiler.settings.kiwishelf.outerMargin = 8
        core.updateBars()
        #expect(core.pocketPlate.slots[display] == nil)
        #expect(!core.pocketStands)
        core.pocketPlate.dragging = one
        core.updateBars()
        #expect(core.pocketStands)
        // Under One window the bar's edge opens no slot: the pocket
        // stands just inside the strip, in a panel of its own (#2793).
        #expect(core.pocketPlate.slots[display] == nil)
        let strip = try #require(core.pocketPlate.barStrips[display])
        let inside = try #require(core.pocketInsideFrame(on: display))
        #expect(inside.maxY <= strip.minY)
        let spec = try #require(core.pocketPlate.specs[display])
        #expect(spec.whole && spec.handle == .bottom && !spec.risen)
        // Drawn at the inside frame, at its edge, sliding out of it.
        let drawn = GeometryUtils.flip(
            spec.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        #expect(drawn == inside)
        #expect(spec.outer == 0 && spec.slides)
        #expect(core.pocketLanding(on: display) == inside)
        #expect(core.pocketPlate.sectionMount(on: display) == nil)
        core.endPocketDrag()
        #expect(core.pocketPlate.specs[display] == nil)
    }

    @Test("under Several the drag finds the pocket in its slot")
    func severalKeepsTheSlot() throws {
        let (core, display) = try makeCore()
        core.execute("pocket.set_capacity", args: [.string("several")])
        core.pocketPlate.dragging = one
        core.updateBars()
        #expect(core.pocketPlate.slots[display] != nil)
        #expect(core.pocketInsideFrame(on: display) == nil)
        #expect(core.pocketPlate.sectionMount(on: display) != nil)
    }

    @Test("the pocket stands on a second display at its own slot")
    func everyDisplayTakesItsSlot() throws {
        let (core, display) = try makeCore()
        core.execute("pocket.set_capacity", args: [.string("several")])
        let second = DisplayID(900_777)
        core.state.workspaces.upsertDisplay(
            Display(
                id: second,
                name: "Second",
                frame: CGRect(x: 1440, y: 0, width: 1440, height: 900)
            )
        )
        let a = CGRect(x: 1400, y: 860, width: 40, height: 40)
        let b = CGRect(x: 2840, y: 860, width: 40, height: 40)
        core.updatePocketPlate(slots: [display: a, second: b])
        #expect(Set(core.pocketPlate.specs.keys) == [display, second])
        #expect(core.pocketPlate.sectionMount(on: display) != nil)
        #expect(core.pocketPlate.sectionMount(on: second) != nil)
        #expect(
            core.pocketPlate.sectionMount(on: display)
                !== core.pocketPlate.sectionMount(on: second)
        )
    }

    @Test("a list grown out of a risen handle survives the pointer leaving")
    func risenListStaysOpen() throws {
        let (core, display) = try makeCore()
        core.tiler.settings.spaceBarStyle.edge = .top
        // Hidden, so the bottom edge rests a handle, not the whole
        // pocket (#2784).
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.execute("pocket.set_capacity", args: [.string("several")])
        core.pocketPlate.ordersPanel = true
        // The handle stands on the real screen's edge.
        core.shelves.peek.visibleArea = { _ in
            CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        }
        defer {
            core.shelves.peek.dismiss()
            core.shelves.peek.panel.panel?.orderOut(nil)
            core.pocketPlate.sync([])
        }
        core.handle(.windowFocused(one))
        core.execute("toggle_pocket_window")
        core.execute("pocket")
        core.updatePocketPlate(slots: [:])
        core.pocketHovered(display, true)
        let view = try #require(core.pocketPlate.view(on: display))
        core.pocketPlate.onClick(view)
        #expect(core.shelves.peek.shown?.view === view)
        // The pointer leaves the handle for the list.
        core.pocketHovered(display, false)
        #expect(core.shelves.peek.shown?.view === view)
        #expect(core.pocketPlate.specs[display]?.risen == true)
    }

    private func spec(
        frame: CGRect,
        windows: [WindowID],
        risen: Bool
    ) -> PocketPlateOverlay.Spec {
        PocketPlateOverlay.Spec(
            display: DisplayID(1),
            windows: windows,
            frame: frame,
            shelf: KiwiShelf(),
            markHex: "",
            faded: windows.isEmpty,
            dropHovered: false,
            name: "",
            handle: .bottom,
            risen: risen,
            risenSide: 32
        )
    }

    @Test("a list holds through a rise or sink, never a move or a change")
    func listHoldsAcrossRise() {
        let risen = CGRect(x: 0, y: 0, width: 64, height: 48)
        let was = spec(frame: risen, windows: [one], risen: true)
        let sunk = spec(
            frame: CGRect(x: 0, y: 32, width: 64, height: 16),
            windows: [one],
            risen: false
        )
        #expect(KiwiCore.pocketListHolds(was: was, now: sunk))
        let moved = spec(
            frame: risen.offsetBy(dx: 200, dy: 0),
            windows: [one],
            risen: true
        )
        #expect(!KiwiCore.pocketListHolds(was: was, now: moved))
        let emptied = spec(frame: risen, windows: [], risen: true)
        #expect(!KiwiCore.pocketListHolds(was: was, now: emptied))
        #expect(!KiwiCore.pocketListHolds(was: was, now: nil))
    }
}
