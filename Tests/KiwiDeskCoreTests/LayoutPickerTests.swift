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
}
