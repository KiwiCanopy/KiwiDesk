import AppKit
import Testing

@testable import KiwiDeskCore

/// The layout picker (#762): a native menu at the pointer, a
/// header naming the Space it acts on, the Layout menu's rows from
/// the one `LayoutModeRows` with the live layout checked, and a
/// pick that sets that Space's layout.
@Suite("Layout picker (#762)")
@MainActor
struct LayoutPickerTests {
    private final class Box {
        var menus: [NSMenu] = []
        var now: TimeInterval = 100
        var tracked: (NSMenuItem?, NSPoint, TimeInterval?)?
    }

    private func makeCore() -> (KiwiCore, Box) {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace("3")
        core.state.workspaces.activate("3")
        core.state.workspaces.setMode("3", .grid)
        let box = Box()
        core.shelves.contextMenus.popUp = { menu, _ in
            box.menus.append(menu)
        }
        return (core, box)
    }

    @Test("it pops one menu: a header, then every layout")
    func popsTheLayoutMenu() throws {
        let (core, box) = makeCore()
        #expect(core.execute("show_layout_picker", args: []).isSuccess)
        let menu = try #require(box.menus.first)
        #expect(box.menus.count == 1)
        let items = menu.items
        #expect(items.first?.isSectionHeader == true)
        #expect(items.first?.title.contains("3") == true)
        let layouts = items.dropFirst()
        #expect(layouts.count == LayoutMode.allCases.count)
        let checked = layouts.filter { $0.state == .on }
        #expect(checked.count == 1)
        let gridIndex = try #require(LayoutMode.allCases.firstIndex(of: .grid))
        #expect(Array(layouts)[gridIndex].state == .on)
    }

    @Test("a pick sets the Space's layout")
    func pickSetsTheLayout() throws {
        let (core, _) = makeCore()
        let rows = core.layoutPickerRows("3")
        let monocle = try #require(
            LayoutMode.allCases.firstIndex(of: .monocle)
        )
        guard case .action(let perform) = rows[monocle + 1].kind else {
            Issue.record("not an action row")
            return
        }
        perform()
        #expect(core.state.workspaces[SpaceID("3")]?.mode == .monocle)
    }

    /// Carbon holds a press made while the menu tracks until it
    /// closes, then delivers it within ms (measured 3–13 ms): that
    /// press is dropped, and a later one opens the menu again.
    @Test("a press queued behind the open menu opens nothing")
    func queuedPressIsDropped() {
        let (core, box) = makeCore()
        let menus = core.shelves.contextMenus
        menus.clock = { box.now }
        menus.pickerClosedAt = 99.99
        #expect(core.execute("show_layout_picker", args: []).isSuccess)
        #expect(box.menus.isEmpty)
        box.now = 100.5
        #expect(core.execute("show_layout_picker", args: []).isSuccess)
        #expect(box.menus.count == 1)
    }

    /// The default pop-up, run as production runs it: on the next
    /// turn it tracks the checked row at the anchor, and stamps the
    /// close only once tracking has returned.
    @Test("the default pop-up places the checked row and stamps the close")
    func defaultPopUpStampsAfterTracking() async {
        let menus = BarContextMenus()
        let box = Box()
        menus.clock = { box.now }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "BSP", action: nil, keyEquivalent: ""))
        let checked = NSMenuItem(title: "Grid", action: nil, keyEquivalent: "")
        checked.state = .on
        menu.addItem(checked)
        menus.track = { _, item, point in
            box.tracked = (item, point, menus.pickerClosedAt)
        }
        let pointer = NSPoint(x: 500, y: 400)
        menus.popUp(menu, pointer)
        #expect(box.tracked == nil)
        await withCheckedContinuation { done in
            DispatchQueue.main.async { done.resume() }
        }
        let seen = box.tracked
        #expect(seen?.0 === checked)
        #expect(seen?.1 == BarContextMenus.pickerAnchor(pointer))
        #expect(seen?.2 == nil)
        #expect(menus.pickerClosedAt == box.now)
    }

    /// AppKit pins the positioning row's top-left to the point; the
    /// anchor puts that corner up and to the left of the pointer so
    /// the pointer lands inside the current row.
    @Test("the pointer lands inside the current row")
    func anchorPutsThePointerInsideTheRow() {
        let pointer = NSPoint(x: 500, y: 400)
        let anchor = BarContextMenus.pickerAnchor(pointer)
        #expect(anchor.x < pointer.x)
        #expect(anchor.y > pointer.y)
    }

    /// The pointer names the screen, the screen names the Space:
    /// on a desk of two, the one under the pointer, not the
    /// focused one. A point on the seam belongs to the upper
    /// screen, as every other pointer reader decides.
    @Test("the screen under the pointer names the Space")
    func pointerPicksTheScreen() {
        let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let below = CGRect(x: 0, y: -800, width: 1000, height: 800)
        let screens = [
            (frame: left, id: DisplayID(1)),
            (frame: right, id: DisplayID(2)),
            (frame: below, id: DisplayID(3)),
        ]
        #expect(
            KiwiCore.display(at: CGPoint(x: 1500, y: 400), among: screens)
                == DisplayID(2)
        )
        #expect(
            KiwiCore.display(at: CGPoint(x: 500, y: 0), among: screens)
                == DisplayID(1)
        )
        #expect(
            KiwiCore.display(at: CGPoint(x: 5000, y: 0), among: screens)
                == nil
        )
    }
}
