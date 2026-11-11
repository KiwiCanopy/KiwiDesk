import Foundation
import Testing

@testable import KiwiDesk

/// Which chips the jump bar draws: every Built-in group's, the
/// macOS Desktops chip only while its section does (#2655). Lua
/// bindings, Open applications and Mouse & Trackpad lost theirs to
/// their parts (#3184).
@Suite("Shortcuts jump: drawn chips")
struct ShortcutsJumpShownTests {
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

    @Test("every chip draws while the Desktops section does")
    func allChipsDraw() {
        #expect(
            ShortcutsJumpGroup.shown(desktopsDrawn: true)
                == ShortcutsJumpGroup.allCases
        )
    }

    /// The macOS Desktops chip follows its section (#2655): a
    /// section removed for want of a bridge has nowhere to jump.
    @Test("the Desktops chip shows only while its section draws")
    func desktopsChipFollowsTheSection() {
        #expect(
            ShortcutsJumpGroup.shown(desktopsDrawn: false)
                == ShortcutsJumpGroup.allCases.filter {
                    $0 != .macosDesktops
                }
        )
    }

    @Test("the bar draws the offered chips")
    func wiring() throws {
        let bar = try Self.source(
            "Components/Keybindings/ShortcutsJumpBar.swift"
        )
        #expect(bar.contains("ForEach(groups,id:\\.self)"))
        let jump = try Self.source("Sections/ShortcutsSection+Jump.swift")
        #expect(
            jump.contains(
                "groups:ShortcutsJumpGroup.shown("
                    + "desktopsDrawn:MacOSDesktopsGroup"
                    + ".hasRows(expander))"
            )
        )
    }
}
