import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// VoiceOver reaches the pocket's rows (#2936): the click-held peek
/// is hidden from accessibility, so the plate's press opens the
/// native menu of the windows inside instead, Pocket Keys included,
/// as a Space Bar list glyph's press does (bars.md ▸ a bar list).
@Suite("The pocket's VoiceOver press opens its menu (#2936)", .serialized)
@MainActor
struct PocketPlateVoiceOverTests {
    typealias Fixture = PocketAppFixture
    private let mine = WindowID(9)
    private let general = WindowID(1)

    /// Several windows: the app's own window pocketed through its
    /// key, another app's put in the general list, the pocket on the
    /// real main screen so its plate stands (#531).
    private func fixture() throws -> Fixture {
        let fixture = Fixture()
        let core = fixture.core
        core.execute("pocket.set_capacity", args: [.string("several")])
        fixture.press()
        fixture.arrive(9)
        fixture.press()
        core.handle(.windowFocused(general))
        core.execute("toggle_pocket_window")
        core.execute("pocket")
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
        core.barMenuHooks.pocketKeyChord = { _ in
            RenderedChord(drawn: "⌃⌥T", spoken: "Control Option T")
        }
        return fixture
    }

    @Test(
        "the press lists every window inside, the keyed one apart",
        .enabled(if: NSScreen.main != nil)
    )
    func pressOpensTheMenu() throws {
        LocalizationManager.shared.select("en")
        let fixture = try fixture()
        let core = fixture.core
        defer { core.pocketPlate.sync([]) }
        var shown: NSMenu?
        var anchor: NSView?
        core.spaceBars.glyphActions.present = { menu, at in
            shown = menu
            anchor = at
        }
        core.updatePocketPlate(slots: [:])
        let display = try #require(core.pocketPlate.specs.keys.first)
        let view = try #require(core.pocketPlate.view(on: display))
        #expect(view.accessibilityPerformPress())
        let menu = try #require(shown)
        #expect(anchor === view)
        // A row per window inside: the general one, then the keyed.
        #expect(menu.items.filter { $0.action != nil }.count == 2)
        #expect(menu.items.contains { $0.isSectionHeader })
        let last = try #require(menu.items.last)
        #expect(
            last.accessibilityLabel()?.hasSuffix("Pocket key Control Option T")
                == true
        )
    }

    /// The press takes the peek's one menu door, so the menu's kind
    /// and keys stay the source's (bars.md ▸ a window menu).
    @Test(
        "the press asks the peek's menu door for the pocket",
        .enabled(if: NSScreen.main != nil)
    )
    func pressTakesTheMenuDoor() throws {
        let fixture = try fixture()
        let core = fixture.core
        defer { core.pocketPlate.sync([]) }
        var asked: [BarPeekSource] = []
        core.shelves.peek.openMenu = { source, _, _ in asked.append(source) }
        core.updatePocketPlate(slots: [:])
        let display = try #require(core.pocketPlate.specs.keys.first)
        let view = try #require(core.pocketPlate.view(on: display))
        #expect(view.accessibilityPerformPress())
        #expect(asked == [.pocket([general, mine])])
    }

    /// A press while the click's list is open closes it, so the
    /// menu is not opened over a list VoiceOver cannot reach.
    @Test(
        "a press over an open list closes the list",
        .enabled(if: NSScreen.main != nil)
    )
    func pressClosesTheList() throws {
        let fixture = try fixture()
        let core = fixture.core
        core.pocketPlate.ordersPanel = true
        core.shelves.peek.visibleArea = { _ in
            CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        }
        defer {
            core.shelves.peek.dismiss()
            core.shelves.peek.panel.panel?.orderOut(nil)
            core.pocketPlate.sync([])
        }
        var menus = 0
        core.spaceBars.glyphActions.present = { _, _ in menus += 1 }
        core.updatePocketPlate(slots: [:])
        let display = try #require(core.pocketPlate.specs.keys.first)
        let view = try #require(core.pocketPlate.view(on: display))
        core.pocketPlate.onClick(view)
        #expect(core.shelves.peek.shown?.view === view)
        #expect(view.accessibilityPerformPress())
        #expect(core.shelves.peek.shown == nil)
        #expect(menus == 1)
    }

    /// The click keeps its list; only the press takes the menu.
    @Test(
        "a click still grows the list and opens no menu",
        .enabled(if: NSScreen.main != nil)
    )
    func clickKeepsTheList() throws {
        let fixture = try fixture()
        let core = fixture.core
        core.pocketPlate.ordersPanel = true
        core.shelves.peek.visibleArea = { _ in
            CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        }
        defer {
            core.shelves.peek.dismiss()
            core.shelves.peek.panel.panel?.orderOut(nil)
            core.pocketPlate.sync([])
        }
        var menus = 0
        core.spaceBars.glyphActions.present = { _, _ in menus += 1 }
        core.updatePocketPlate(slots: [:])
        let display = try #require(core.pocketPlate.specs.keys.first)
        let view = try #require(core.pocketPlate.view(on: display))
        core.pocketPlate.onClick(view)
        #expect(core.shelves.peek.shown?.view === view)
        #expect(menus == 0)
    }
}
