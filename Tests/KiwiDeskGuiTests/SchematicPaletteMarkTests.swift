import SwiftUI
import Testing

@testable import KiwiDesk

/// The brand marks a plate draws (#2859, #2871): on the light plate
/// `accentMark` and `boundKeyEdge` are the measured `lightAccent`,
/// on the dark one the theme accent and no edge. The contrast suite
/// measures the token; this holds the palette to using it.
@Suite("Schematic palette marks")
@MainActor
struct SchematicPaletteMarkTests {
    private func palette(_ ground: PlateGround) -> SchematicPalette {
        SchematicPalette(
            accent: .pink,
            ink: .white,
            base: .black,
            ground: ground
        )
    }

    @Test("the light plate's marks are lightAccent")
    func lightMarks() {
        #expect(palette(.light).accentMark == SettingsTheme.lightAccent)
        #expect(palette(.light).boundKeyEdge == SettingsTheme.lightAccent)
    }

    @Test("the dark plate's mark is the accent, with no key edge")
    func darkMarks() {
        #expect(palette(.dark).accentMark == SettingsTheme.accent)
        #expect(palette(.dark).boundKeyEdge == .clear)
    }
}
