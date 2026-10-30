import Foundation
import Testing

@testable import KiwiDesk

/// The Liquid Glass switch points at macOS's own Liquid Glass
/// slider, which the glass follows (ui-designer, 2026-10-30): a
/// link in the sentence, drawn under the switch wherever glass is.
@Suite("The Liquid Glass switch points at macOS's slider")
struct GlassSystemPointerTests {
    @Test("the sentence carries the link slot exactly once")
    func proseHasTheSlot() {
        let prose = GlassSystemPointer.prose
        #expect(prose.occurrences(of: CrossReferenceRow.linkSlot) == 1)
    }

    @Test("the link opens System Settings' Appearance pane")
    func linkOpensAppearance() {
        #expect(
            GlassSystemPointer.appearancePane.absoluteString
                == "x-apple.systempreferences:"
                + "com.apple.Appearance-Settings.extension"
        )
    }

    @Test("the card draws the pointer under the switch alone")
    func cardMountsThePointer() throws {
        let card = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/Looks/"
                            + "GlassCard.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(card.occurrences(of: "GlassSystemPointer()") == 1)
        #expect(
            card.occurrences(
                of: "if AppBarStyle.glassAvailable, "
                    + "key == .colours(.liquidGlassMaster) {\n"
                    + "            GlassSystemPointer()"
            ) == 1
        )
    }
}
