import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `pocket.toggle_list` (#2974 ▸ Ruling): a key opens the pocket's list
/// wherever the pocket is, on that one screen; no bar moves and no
/// window, and a stand-down refuses.
@Suite(
    "The pocket's list by key",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketListKeyTests {
    private let one = WindowID(1)

    @Test("under One window the key stands the pocket and closes it again")
    func oneWindowStandsAndCloses() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        core.updateBars()
        #expect(!core.pocketStands)
        let held = core.shelfReservations
        #expect(core.execute("pocket.toggle_list").error == nil)
        let view = try #require(core.pocketPlate.view(on: display))
        #expect(core.shelves.peek.shown?.view === view)
        #expect(core.shelves.peek.shown?.edge == .bottom)
        #expect(core.pocketListDisplay == display)
        #expect(core.pocketStands)
        // The bars' plan stays capacity-only: no slot, no reservation.
        #expect(core.shelfReservations == held)
        #expect(core.execute("pocket.toggle_list").error == nil)
        #expect(core.shelves.peek.shown == nil)
        #expect(!core.pocketStands)
        #expect(core.pocketPlate.specs[display] == nil)
    }

    @Test("under One window a bar's edge opens no slot for the list")
    func barEdgeOpensNoSlot() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        core.tiler.settings.spaceBarStyle.edge = .bottom
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.updateBars()
        core.execute("pocket.toggle_list")
        #expect(core.pocketListDisplay == display)
        #expect(core.pocketPlate.slots[display] == nil)
        // The bar pass placed it, on the strip it stands inside.
        let inside = try #require(core.pocketInsideFrame(on: display))
        let spec = try #require(core.pocketPlate.specs[display])
        #expect(
            GeometryUtils.flip(
                spec.frame,
                primaryHeight: GeometryUtils.primaryHeight
            ) == inside
        )
    }

    @Test("the key closes a list open on another screen, opening none")
    func closesAnotherScreensList() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        core.execute("pocket.toggle_list")
        #expect(core.pocketListDisplay == display)
        let second = DisplayID(900_777)
        core.state.workspaces.upsertDisplay(
            Display(
                id: second,
                name: "Second",
                frame: CGRect(x: 40_000, y: 0, width: 1440, height: 900)
            )
        )
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.assign(space, to: second)
        #expect(core.execute("pocket.toggle_list").isSuccess)
        #expect(core.shelves.peek.shown == nil)
    }

    /// A setter's dispatch ends in a forced pass, which drops learned
    /// bounds and re-laid a tiled Space on every press (device).
    @Test("opening and closing the list runs no layout pass")
    func runsNoPass() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        #expect(core.execute("pocket.toggle_list").isSuccess)
        #expect(core.shelves.peek.shown != nil)
        #expect(core.execute("pocket.toggle_list").isSuccess)
        let counts = meter.snapshot(reset: false).counts
        #expect(counts.retiles + counts.passesHeld == 0)
        // Opening does owe the bar pass that places the pocket.
        #expect(counts.barRenders > 0)
    }

    @Test("the list stands its pocket on the active screen alone")
    func oneScreenStands() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        let second = DisplayID(900_777)
        core.state.workspaces.upsertDisplay(
            Display(
                id: second,
                name: "Second",
                frame: CGRect(x: 40_000, y: 0, width: 1440, height: 900)
            )
        )
        core.execute("pocket.toggle_list")
        #expect(core.pocketListDisplay == display)
        #expect(core.pocketStands(on: display))
        #expect(!core.pocketStands(on: second))
        #expect(Set(core.pocketPlate.specs.keys) == [display])
    }

    @Test("on a bar's edge the list opens off its section, the bar kept")
    func sectionOpens() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        core.shelves.ordersPanels = true
        core.tiler.settings.spaceBarStyle.edge = .bottom
        core.tiler.settings.spaceBarStyle.visibility = .always
        fixture.pocket([one])
        core.updateBars()
        let slot = try #require(core.pocketPlate.slots[display])
        let strips = core.spaceBars.shownStrips.map(\.strip)
        core.execute("pocket.toggle_list")
        #expect(core.pocketListDisplay == display)
        #expect(core.pocketPlate.specs[display]?.handle == nil)
        #expect(core.pocketPlate.slots[display] == slot)
        #expect(core.spaceBars.shownStrips.map(\.strip) == strips)
        core.execute("pocket.toggle_list")
        #expect(core.shelves.peek.shown == nil)
    }

    @Test("under One window the key's list holds an app's own window")
    func oneWindowListsKeyed() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one])
        core.state.pocket = core.state.pocket.map {
            var slot = $0
            slot.keyedApp = "com.example.app"
            return slot
        }
        core.execute("pocket.set_capacity", args: [.string("one")])
        #expect(core.pocketPlateWindows.isEmpty)
        core.execute("pocket.toggle_list")
        let panel = core.shelves.peek.panel
        #expect(panel.drawn?.empty == nil)
        #expect(panel.drawn?.groups.last?.keyed == true)
        #expect(panel.drawn?.groups.last?.rows.map(\.window) == [one])
    }

    @Test("a key held through a Desktop switch's read keeps its repaint")
    func keepsTheSwitchRepaint() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer {
            fixture.tearDown()
            core.eventLoop.switchReads.drop()
        }
        core.eventLoop.beginSwitchReconcile()
        #expect(core.eventLoop.switchReads.isPending)
        core.execute("pocket.toggle_list")
        #expect(core.pocketListDisplay == display)
        #expect(core.eventLoop.switchReads.barsOwed)
    }

    @Test("a handle's pocket rises for the key's list and sinks after it")
    func handleRises() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        fixture.pocket([one])
        #expect(core.pocketPlate.specs[display]?.risen == false)
        // Risen before the list reads its content, so it grows out of
        // the risen pocket, and held there by the open list after.
        let content = core.shelves.peek.content
        var risenAtOpen: Bool?
        core.shelves.peek.content = { source, space in
            risenAtOpen = core.pocketPlate.specs[display]?.risen
            return content(source, space)
        }
        core.execute("pocket.toggle_list")
        #expect(risenAtOpen == true)
        #expect(core.pocketListDisplay == display)
        core.updatePocketPlate()
        #expect(core.pocketPlate.specs[display]?.risen == true)
        core.execute("pocket.toggle_list")
        #expect(core.pocketPlate.specs[display]?.risen == false)
    }

    @Test("an empty pocket shows its empty state, its first row lifted")
    func emptyShowsItsState() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        core.execute("pocket.toggle_list")
        let panel = core.shelves.peek.panel
        #expect(panel.drawn?.empty != nil)
        #expect(panel.body.hovered == 0)
    }

    @Test("a stand-down refuses with no list and no pocket")
    func standDownRefuses() throws {
        LocalizationManager.shared.select("en")
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        var spoken: [String] = []
        core.borders.announceRefusal = { spoken.append($0) }
        NativeSpaces.currentSpaceIsUserOverride = { _ in false }
        #expect(
            core.execute("pocket.toggle_list").error
                == "the pocket stays hidden while a window fills the screen"
        )
        #expect(core.shelves.peek.shown == nil)
        #expect(core.pocketPlate.specs[display] == nil)
        #expect(core.pocketPlate.openingList == nil)
        #expect(
            spoken
                == ["The Pocket stays hidden while a window fills the screen"]
        )
    }

    @Test("a list that cannot open leaves no pocket standing for it")
    func failedOpenLeavesNothing() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        core.shelves.peek.content = { _, _ in nil }
        #expect(core.execute("pocket.toggle_list").error != nil)
        #expect(core.pocketPlate.openingList == nil)
        #expect(!core.pocketStands)
        #expect(core.pocketPlate.specs[display] == nil)
    }

    /// The list closing inside a sync: that sync's specs were read with
    /// the list holding the pocket.
    @Test("a list a change closes takes its One-window pocket with it")
    func closedListLeavesInTheSamePass() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        core.handle(.windowFocused(one))
        core.execute("toggle_pocket_window")
        core.execute("pocket")
        #expect(core.state.isPocketed(one))
        core.execute("pocket.toggle_list")
        #expect(core.pocketListDisplay == display)
        core.state.apply(.windowDestroyed(one, wasMinimized: false))
        core.updatePocketPlate()
        #expect(core.shelves.peek.shown == nil)
        #expect(core.pocketPlate.specs[display] == nil)
    }

    @Test("it acts on no window: out of the foreground preflight")
    func noFocusImplied() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        #expect(!core.impliesFocus("pocket.toggle_list", []))
    }
}
