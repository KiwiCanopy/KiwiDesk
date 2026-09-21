import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The space icon picker previews on the Space Bar's plate, in
/// the bar's own ink (#1485, #702): a symbol takes `item_color`,
/// an emoji stays untinted at the bar's dim, and an empty icon
/// previews the identifier the bar falls back to — Core's ladder,
/// never a reading of the picker's own.
///
/// `@MainActor` because `KiwiCore` is; the suite spends only a
/// few `NSImage(systemSymbolName:)` lookups there.
@Suite("Icon picker bar-plate preview")
@MainActor
struct IconPickerBarPlateTests {
    private var style: SpaceBarStyle {
        var style = SpaceBarStyle()
        style.itemColor = "#123456"
        style.dimFactor = 0.42
        return style
    }

    @Test("A symbol and tinted text take item_color at full strength")
    func tintedGlyphsTakeTheItemColor() {
        let style = self.style
        let symbol = BarPlateGlyph.ink(of: .symbol("book"), in: style)
        #expect(symbol.hex == "#123456")
        #expect(symbol.opacity == 1)
        let digits = BarPlateGlyph.ink(
            of: .text("4", tinted: true),
            in: style
        )
        #expect(digits.hex == "#123456")
        #expect(digits.opacity == 1)
    }

    @Test("An untinted glyph keeps its own colours at the bar's dim")
    func untintedGlyphIsDimmedNotTinted() {
        let ink = BarPlateGlyph.ink(
            of: .text("⭐", tinted: false),
            in: style
        )
        #expect(ink.hex == nil)
        #expect(ink.opacity == 0.42)
    }

    /// End to end through the ladder the swatch consults: the
    /// icon strings a user picks, classified by Core.
    @Test("The swatch's glyph is Core's verdict on the picked icon")
    func swatchGlyphIsCoresVerdict() {
        let space = SpaceID("mail")
        #expect(
            KiwiCore.spaceIdentifier(id: space, icon: "book")
                == .symbol("book")
        )
        #expect(
            KiwiCore.spaceIdentifier(id: space, icon: "⭐")
                == .text("⭐", tinted: false)
        )
        #expect(
            KiwiCore.spaceIdentifier(id: space, icon: "")
                == .text("MA", tinted: true)
        )
        #expect(
            KiwiCore.spaceIdentifier(id: SpaceID("3"), icon: nil)
                == .text("3", tinted: true)
        )
    }

    // MARK: - Seam

    private var guiRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private func squashed(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: guiRoot.appendingPathComponent(path),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    /// The plate swatch classifies through Core's one ladder and
    /// paints the plate in the style's fill — a preview claiming
    /// the bar's behaviour calls the bar (#702) — and the Spaces
    /// row hands the picker the draft's style, so the preview
    /// follows the palette being edited rather than a saved one.
    @Test("The swatch takes Core's ladder and the draft's style")
    func swatchIsWiredToCoreAndTheDraft() throws {
        let preview = try squashed(
            "Components/Icons/IconPicker+Preview.swift"
        )
        #expect(
            preview.components(
                separatedBy: "KiwiCore.spaceIdentifier("
            ).count == 2
        )
        #expect(preview.contains(".fill(Color(kiwiHex:style.fillColor))"))
        #expect(!preview.contains("iconIsSymbol("))
        let spaces = try squashed("Sections/SpacesSection.swift")
        #expect(
            spaces.contains(
                "preview:.spaceBar(model.config.settings.spaceBarStyle,"
            )
        )
    }
}
