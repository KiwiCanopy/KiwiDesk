import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Which recognised rows a binding's `group` may move (#2544 ▸
/// Ruling): a working row moves to the group it names, while an
/// inactive or Desktop-away row keeps the section that says it
/// does not work, and a group naming the row's own band moves
/// nothing.
@Suite("A binding's group moves only working rows (#2544)", .serialized)
@MainActor
struct ShortcutRegroupScopeTests {
    private func reference(
        _ bindings: [KeyBinding],
        desktops: [Int] = [1]
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: KeyLayer.defaultName, bindings: bindings),
            spaces: [SpaceID("1")],
            spaceIcons: [:],
            desktops: desktops,
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
    }

    private func row(
        _ combo: String,
        _ lua: String,
        group: String
    ) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation, group: group)
    }

    @Test("An inactive row keeps the Inactive section")
    func inactiveStays() {
        LocalizationManager.shared.select("en")
        let built = reference([
            row("ctrl+alt+6", "KiwiDesk.focus_space(\"6\")", group: "Mine")
        ])
        #expect(built.inactive.count == 1)
        #expect(built.groups.isEmpty)
    }

    @Test("A Desktop-away row keeps the Unavailable section")
    func awayStays() throws {
        LocalizationManager.shared.select("en")
        let lua = try #require(KeybindingCatalog.goToDesktop([5]).first?.lua)
        let built = reference([row("ctrl+alt+5", lua, group: "Mine")])
        #expect(built.desktopAway.count == 1)
        #expect(built.groups.isEmpty)
    }

    @Test("Open Settings keeps KiwiDesk's own app mark when moved")
    func ownAppMoves() throws {
        LocalizationManager.shared.select("en")
        let built = reference([
            row(
                "ctrl+alt+comma",
                KeybindingCatalog.openSettings.lua,
                group: "Mine"
            )
        ])
        let mine = try #require(built.groups.first { $0.title == "Mine" })
        #expect(mine.rows.first?.ownApp == true)
    }

    @Test("Its own band's token moves nothing; another band's moves it")
    func builtInTokens() throws {
        LocalizationManager.shared.select("en")
        let lua = "KiwiDesk.focus(\"left\")"
        let plain = reference([KeyBinding(combo: "alt+h", lua: lua)])
        let same = reference([row("alt+h", lua, group: "focus")])
        func focusIDs(_ built: ShortcutsReference) -> [String] {
            built.controls.first { $0.group == .focus }?.rows.map(\.id)
                ?? []
        }
        #expect(focusIDs(same) == focusIDs(plain))
        let moved = reference([row("alt+h", lua, group: "layout")])
        #expect(!focusIDs(moved).contains(lua))
        let layout = try #require(
            moved.controls.first { $0.group == .layout }
        )
        #expect(layout.rows.contains { $0.id == lua })
    }

    /// Four directions folded into one row move together when each
    /// names the same group.
    @Test("A folded row moves when every member names the group")
    func foldedRowMoves() throws {
        LocalizationManager.shared.select("en")
        let bindings = [
            ("alt+h", "left"), ("alt+j", "down"),
            ("alt+k", "up"), ("alt+l", "right"),
        ].map { combo, dir in
            row(combo, "KiwiDesk.focus(\"\(dir)\")", group: "layout")
        }
        let built = reference(bindings)
        #expect(built.controls.first { $0.group == .focus } == nil)
        let layout = try #require(
            built.controls.first { $0.group == .layout }
        )
        let moved = layout.rows.flatMap {
            $0.members.isEmpty ? [$0.id] : $0.members.map(\.id)
        }
        #expect(moved.filter { $0.hasPrefix("KiwiDesk.focus(") }.count == 4)
    }
}
