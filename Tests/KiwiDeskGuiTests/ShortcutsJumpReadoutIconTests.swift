import Foundation
import Testing

@testable import KiwiDesk

/// The jump bar's editing readout leads with the edited layer's
/// icon (#3431): the one `KeyLayer.icons` reading, which leaves out
/// `default` and a layer without one, drawn ahead of the whole
/// sentence through the glyph door, with VoiceOver hearing the
/// sentence alone. Source needles, whitespace stripped.
@Suite("Shortcuts jump readout icon (#3431)")
struct ShortcutsJumpReadoutIconTests {
    private func flat(_ path: String) throws -> String {
        let text = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk/" + path)
        )
        .filter { !$0.isWhitespace }
        #expect(!text.isEmpty)
        return text
    }

    @Test("the bar is handed the edited layer's icon")
    func wiring() throws {
        let jump = try flat("Settings/Sections/ShortcutsSection+Jump.swift")
        #expect(
            jump.contains(
                "readoutIcon:ShortcutGlyph(layer:selected,"
                    + "in:model.config.layers)"
            )
        )
    }

    @Test("the icon leads the sentence and is not spoken")
    func drawing() throws {
        let bar = try flat(
            "Settings/Components/Keybindings/ShortcutsJumpBar.swift"
        )
        #expect(
            bar.contains(
                "HStack(alignment:.firstTextBaseline,spacing:4){"
                    + "ifletreadoutIcon{ShortcutGlyphView(glyph:readoutIcon,"
                    + "side:ShortcutLayerChip.iconSide)}Text(text)}"
            )
        )
        #expect(
            bar.contains(
                ".accessibilityElement(children:.ignore)"
                    + ".accessibilityLabel(spokenReadout??text)"
            )
        )
    }
}
