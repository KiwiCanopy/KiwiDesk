import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Mouse & trackpad ▸ hover focus's delay (#2379): the row rides
/// the hover focus entry under its switch, writes the stored value
/// the Lua verb writes, greys — never hides — while hover focus is
/// off, and takes its floor from Core.
@Suite("Hover delay row wiring (#2379)")
struct GesturesHoverDelayWiringTests {
    private static func drawer() throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/Gestures/"
                            + "GesturesDrawer.swift"
                    ),
                encoding: .utf8
            )
        )
    }

    @Test("the row sits in the hover focus entry, under the switch")
    func rowRidesTheEntry() throws {
        let entries = try #require(
            SourceScan.declarationBody(
                after: "@ViewBuilder private var focusEntries",
                in: try Self.drawer()
            )
        )
        let toggle = try #require(
            entries.range(of: "$model.config.settings.mouse.hoverFocus")
        )
        let row = try #require(entries.range(of: "hoverDelayRow"))
        // Inside the entry's control, ahead of the rule that ends it.
        let rule = try #require(entries.range(of: "GestureRule()"))
        #expect(toggle.lowerBound < row.lowerBound)
        #expect(row.lowerBound < rule.lowerBound)
    }

    @Test("the row writes the delay and greys while hover focus is off")
    func rowGreys() throws {
        let drawer = try Self.drawer()
        let row = try #require(
            SourceScan.declarationBody(
                after: "var hoverDelayRow",
                in: drawer
            )
        )
        #expect(row.contains("$model.config.settings.mouse.hoverFocusDelayMS"))
        #expect(
            row.contains(".disabled(!model.config.settings.mouse.hoverFocus)")
        )
        let hides = try NSRegularExpression(
            pattern: "\\bif\\b[^\\n{]*mouse\\.hoverFocus\\b"
        )
        #expect(
            hides.numberOfMatches(
                in: drawer,
                range: NSRange(drawer.startIndex..., in: drawer)
            ) == 0
        )
    }

    @Test("the floor is Core's")
    @MainActor
    func floorIsCore() {
        #expect(
            GesturesDrawer.hoverDelayRange.lowerBound
                == MouseSettings.hoverFocusDelayFloorMS
        )
        let below = MouseSettings.hoverFocusDelayFloorMS - 50
        var mouse = MouseSettings()
        mouse.hoverFocusDelayMS = below
        #expect(
            mouse.hoverFocusDelayMS == MouseSettings.hoverFocusDelayFloorMS
        )
    }
}
