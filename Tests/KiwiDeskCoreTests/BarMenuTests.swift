import AppKit
import Testing

@testable import KiwiDeskCore

/// A bar menu's two routes from one row list (#1518): the
/// `NSMenu` states every row's enablement with auto-enabling off at
/// every level (#802), and VoiceOver's actions are the same rows.
@Suite("Bar menu rows")
@MainActor
struct BarMenuTests {
    private func rows(_ log: @escaping (String) -> Void) -> [BarMenuRow] {
        [
            .submenu(
                "Layout",
                [
                    .action("BSP", checked: true) { log("bsp") },
                    .action("Grid") { log("grid") },
                ]
            ),
            .action("Greyed", enabled: false) { log("greyed") },
            .separator,
            .action("Looks…") { log("looks") },
        ]
    }

    @Test("the menu states each row and never auto-enables")
    func menuShape() throws {
        var fired: [String] = []
        let menu = BarMenu.make(rows { fired.append($0) })
        #expect(!menu.autoenablesItems)
        #expect(
            menu.items.map(\.title) == ["Layout", "Greyed", "", "Looks…"]
        )
        #expect(menu.items[1].isEnabled == false)
        #expect(menu.items[2].isSeparatorItem)
        let layout = try #require(menu.items[0].submenu)
        #expect(!layout.autoenablesItems)
        #expect(layout.items.map(\.state) == [.on, .off])
        let grid = layout.items[1]
        let target = try #require(grid.target as? NSObject)
        let action = try #require(grid.action)
        target.perform(action, with: grid)
        #expect(fired == ["grid"])
    }

    /// VoiceOver lists what the menu offers, a nested row named
    /// after its parent, and never a greyed one.
    @Test("VoiceOver's actions are the enabled rows")
    func accessibilityActions() throws {
        LocalizationManager.shared.select("en")
        var fired: [String] = []
        let actions = BarMenu.accessibilityActions(rows { fired.append($0) })
        #expect(
            actions.map(\.name)
                == ["Layout: BSP, current", "Layout: Grid", "Looks…"]
        )
        let looks = try #require(actions.last)
        #expect(looks.handler?() == true)
        #expect(fired == ["looks"])
    }
}
