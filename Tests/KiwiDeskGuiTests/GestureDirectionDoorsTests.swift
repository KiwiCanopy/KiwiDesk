import Foundation
import Testing

@testable import KiwiDesk

/// A gesture direction's picker (#3321): it offers App… and Lua…,
/// as a one-action row's does, and the dim a family row sets on a
/// direction reaches its trigger, never the picker it opens. Wiring
/// no model clause can see, so it is pinned in the source.
@Suite("Gesture direction doors")
struct GestureDirectionDoorsTests {
    private static let gestures =
        "Sources/KiwiDesk/Settings/Components/Gestures/"

    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
        )
    }

    private static func body(
        _ opener: String,
        in path: String
    ) throws -> String {
        try #require(
            SourceScan.declarationBody(after: opener, in: source(path)),
            "\(opener) is gone from \(path)"
        )
    }

    @Test("a direction's picker offers App… and Lua…")
    func doorsAreWired() throws {
        let doors = Self.gestures + "GestureDirectionRow+Doors.swift"
        let menu = try Self.body("var actionMenu: some View", in: doors)
        #expect(menu.contains("onApp: { choosingApp = true }"))
        #expect(menu.contains("onLua: startLua"))
        #expect(menu.contains("onEditLua:"))
        let row = try Self.source(
            Self.gestures + "GestureDirectionRows.swift"
        )
        #expect(row.contains("actionContainer"))
        #expect(!row.contains("SequenceActionMenu("))
        // Every write of a direction goes through the one arm edit,
        // which drops blank Lua and folds back into a family.
        let pick = try Self.body(
            "func pick(_ arm: LuaAction)",
            in: Self.gestures + "GestureDirectionRows.swift"
        )
        #expect(pick.contains("GestureListEdits.arm("))
        #expect(!pick.contains("arms[direction]"))
    }

    @Test("the picker resets the ink its trigger was handed")
    func pickerKeepsItsInk() throws {
        let menu = try Self.body(
            "var body: some View",
            in: "Sources/KiwiDesk/Settings/Components/Keybindings/"
                + "Sequences/SequenceActionMenu.swift"
        )
        let popover = try #require(
            menu.range(of: ".popover(item: $request)")
        )
        let rest = String(menu[popover.upperBound...])
        let ink = try #require(
            rest.range(of: ".foregroundStyle(SettingsTheme.ink)")
        )
        let chrome = try #require(
            rest.range(of: ".settingsPopoverChrome()")
        )
        #expect(ink.lowerBound < chrome.lowerBound)
    }
}
