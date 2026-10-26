import Foundation
import Testing

@testable import KiwiDesk

/// The jump bar's Lua bindings chip (#2544): last, drawn only while
/// the drawer is offered — hidden, not greyed, with nowhere to jump —
/// and a jump opens the drawer it lands on.
@Suite("Shortcuts jump: Lua bindings chip")
struct ShortcutsJumpLuaTests {
    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/\(path)"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    @Test("the chip is last, and only while the drawer is offered")
    func chipFollowsTheOffer() {
        #expect(
            ShortcutsJumpGroup.shown(
                luaDrawerOffered: true,
                desktopsDrawn: true
            ) == ShortcutsJumpGroup.allCases
        )
        #expect(ShortcutsJumpGroup.allCases.last == .luaBindings)
        #expect(
            ShortcutsJumpGroup.shown(
                luaDrawerOffered: false,
                desktopsDrawn: true
            )
                == ShortcutsJumpGroup.allCases.filter {
                    $0 != .luaBindings
                }
        )
    }

    /// The macOS Desktops chip follows its section (#2655): a
    /// section removed for want of a bridge has nowhere to jump.
    @Test("the Desktops chip shows only while its section draws")
    func desktopsChipFollowsTheSection() {
        #expect(
            ShortcutsJumpGroup.shown(
                luaDrawerOffered: true,
                desktopsDrawn: false
            )
                == ShortcutsJumpGroup.allCases.filter {
                    $0 != .macosDesktops
                }
        )
    }

    @Test("the bar draws the offered chips, and a jump opens the drawer")
    func wiring() throws {
        let bar = try Self.source(
            "Components/Keybindings/ShortcutsJumpBar.swift"
        )
        #expect(bar.contains("ForEach(groups,id:\\.self)"))
        let jump = try Self.source("Sections/ShortcutsSection+Jump.swift")
        #expect(
            jump.contains(
                "groups:ShortcutsJumpGroup.shown("
                    + "luaDrawerOffered:offersAdvancedDrawer,"
                    + "desktopsDrawn:MacOSDesktopsGroup"
                    + ".hasRows(expander))"
            )
        )
        #expect(
            jump.contains("ifgroup==.luaBindings{advancedExpanded=true}")
        )
        let section = try Self.source("Sections/ShortcutsSection.swift")
        #expect(
            section.contains(
                ".reportsSectionFrame("
                    + "SettingsCatalog.shortcuts.luaBindings.control)"
            )
        )
    }
}
