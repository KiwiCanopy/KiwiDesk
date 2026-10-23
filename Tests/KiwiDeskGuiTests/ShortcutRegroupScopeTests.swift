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

    private func focusIDs(_ built: ShortcutsReference) -> [String] {
        (built.controls.first { $0.group == .focus }?.rows ?? [])
            .flatMap { $0.members.isEmpty ? [$0.id] : $0.members.map(\.id) }
    }

    private static func focus(_ dir: String) -> String {
        "KiwiDesk.focus(\"\(dir)\")"
    }

    /// Two Focus rows, so a row taken out and put back at the band's
    /// end changes the order.
    @Test("Its own band's token moves nothing; another band's moves it")
    func builtInTokens() throws {
        LocalizationManager.shared.select("en")
        let right = KeyBinding(combo: "alt+l", lua: Self.focus("right"))
        let plain = reference([
            KeyBinding(combo: "alt+h", lua: Self.focus("left")), right,
        ])
        let same = reference([
            row("alt+h", Self.focus("left"), group: "focus"), right,
        ])
        #expect(focusIDs(plain).count == 2)
        #expect(focusIDs(same) == focusIDs(plain))
        let moved = reference([
            row("alt+h", Self.focus("left"), group: "layout"), right,
        ])
        #expect(focusIDs(moved) == [Self.focus("right")])
        let layout = try #require(
            moved.controls.first { $0.group == .layout }
        )
        #expect(layout.rows.contains { $0.id == Self.focus("left") })
    }

    /// One member of a fold naming a group leaves alone, a built-in
    /// token as a group of its own does; the rest keep their band.
    @Test("One member of a fold moves alone, by any group")
    func foldMemberMovesAlone() throws {
        LocalizationManager.shared.select("en")
        for group in ["layout", "Mine"] {
            let bindings = [
                ("alt+h", "left"), ("alt+j", "down"),
                ("alt+k", "up"), ("alt+l", "right"),
            ].map { combo, dir in
                dir == "left"
                    ? row(combo, Self.focus(dir), group: group)
                    : KeyBinding(combo: combo, lua: Self.focus(dir))
            }
            let built = reference(bindings)
            let stayed = focusIDs(built)
            #expect(stayed.count == 3, "\(group)")
            #expect(!stayed.contains(Self.focus("left")), "\(group)")
            let target =
                built.controls.first { $0.group?.rawValue == group }?.rows
                ?? built.groups.first { $0.title == group }?.rows ?? []
            #expect(target.map(\.id) == [Self.focus("left")], "\(group)")
        }
    }

    /// Four directions each naming the same group all move.
    @Test("Every member of a fold naming the group moves")
    func foldedRowMoves() throws {
        LocalizationManager.shared.select("en")
        let bindings = [
            ("alt+h", "left"), ("alt+j", "down"),
            ("alt+k", "up"), ("alt+l", "right"),
        ].map { combo, dir in
            row(combo, Self.focus(dir), group: "layout")
        }
        let built = reference(bindings)
        #expect(focusIDs(built).isEmpty)
        let layout = try #require(
            built.controls.first { $0.group == .layout }
        )
        let moved = layout.rows.flatMap {
            $0.members.isEmpty ? [$0.id] : $0.members.map(\.id)
        }
        #expect(moved.filter { $0.hasPrefix("KiwiDesk.focus(") }.count == 4)
    }
}
