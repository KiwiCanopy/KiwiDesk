import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An empty Pocket on screen (#2941 ▸ Ruling 1): its click and its
/// VoiceOver press both grow the empty state, never a menu, and a
/// row lands on Settings through the GUI's one door.
@Suite("An empty Pocket's plate grows its empty state", .serialized)
@MainActor
struct PocketEmptyPlateTests {
    /// Several windows, nothing inside, the plate on the real main
    /// screen so it stands (#531).
    private func core() throws -> KiwiCore {
        let core = makeTestCore()
        core.execute("pocket.set_capacity", args: [.string("several")])
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
        core.pocketPlate.ordersPanel = true
        core.shelves.peek.visibleArea = { _ in
            CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        }
        core.updatePocketPlate(slots: [:])
        return core
    }

    private func plate(_ core: KiwiCore) throws -> PocketPlateView {
        let display = try #require(core.pocketPlate.specs.keys.first)
        return try #require(core.pocketPlate.view(on: display))
    }

    private func tearDown(_ core: KiwiCore) {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
        core.pocketPlate.sync([])
    }

    @Test(
        "VoiceOver's press grows the empty state, no menu",
        .enabled(if: NSScreen.main != nil)
    )
    func pressGrowsTheEmptyState() throws {
        let core = try core()
        defer { tearDown(core) }
        var menus = 0
        core.spaceBars.glyphActions.present = { _, _ in menus += 1 }
        let view = try plate(core)
        #expect(view.accessibilityPerformPress())
        #expect(core.shelves.peek.shown?.view === view)
        #expect(core.shelves.peek.panel.drawn?.empty != nil)
        #expect(menus == 0)
        // The empty state speaks, so its panel is reachable.
        let panel = core.shelves.peek.panel.panel
        #expect(panel?.isAccessibilityElement() == true)
        // A hover peek the same panel shows next stays hidden.
        core.shelves.peek.dismiss()
        let area = CGRect(x: 0, y: 0, width: 1440, height: 900)
        core.shelves.peek.panel.show(
            BarPeekContent(rows: []),
            shelf: KiwiShelf(),
            edge: .bottom,
            anchor: CGRect(x: 100, y: 0, width: 20, height: 20),
            strip: CGRect(x: 0, y: 0, width: 1440, height: 30),
            visible: area,
            fades: false
        )
        #expect(panel?.isAccessibilityElement() == false)
    }

    @Test(
        "a click grows the empty state; a row lands on Settings",
        .enabled(if: NSScreen.main != nil)
    )
    func rowLandsOnSettings() throws {
        let core = try core()
        defer { tearDown(core) }
        var landed: [SettingsLanding] = []
        core.barMenuHooks.openSettings = { landed.append($0) }
        let view = try plate(core)
        core.pocketPlate.onClick(view)
        #expect(core.shelves.peek.shown?.view === view)
        core.shelves.peek.panel.body.act(.landing(.pocketKeys))
        #expect(landed == [.pocketKeys])
        #expect(core.shelves.peek.shown == nil)
    }
}
