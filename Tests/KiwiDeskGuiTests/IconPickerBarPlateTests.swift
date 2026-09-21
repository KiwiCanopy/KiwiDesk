import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The space icon picker previews on the Space Bar's plate
/// (#1485, #702): the glyph is classified by Core's identifier
/// ladder and inked by Core's one ink door, at rest, over the
/// draft's fill. The verdicts themselves are Core's
/// (`SpaceGlyphInkTests`); this suite pins the WIRING, since a
/// preview that keeps a copy beside the door stays green there.
@Suite("Icon picker bar-plate preview")
struct IconPickerBarPlateTests {
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

    private func count(_ needle: String, in s: String) -> Int {
        s.components(separatedBy: needle).count - 1
    }

    /// The plate swatch classifies through Core's one ladder,
    /// paints the plate in the style's fill, and reads its ink
    /// from the door at rest — consuming BOTH halves of the
    /// verdict, never a colour or an alpha of its own.
    @Test("The swatch takes Core's ladder and ink door, at rest")
    func swatchIsWiredToCore() throws {
        let preview = try squashed(
            "Components/Icons/IconPicker+Preview.swift"
        )
        #expect(count("KiwiCore.spaceIdentifier(", in: preview) == 1)
        #expect(preview.contains(".fill(Color(kiwiHex:style.fillColor))"))
        #expect(count(".identifierInk(", in: preview) == 1)
        #expect(preview.contains("state:.resting)"))
        #expect(preview.contains("ink.hex.map{Color(kiwiHex:$0)}"))
        #expect(preview.contains(".opacity(ink.alpha)"))
        for copy in ["iconIsSymbol(", "dimFactor", "itemColor"] {
            #expect(
                !preview.contains(copy),
                Comment(rawValue: "the preview spells \(copy)")
            )
        }
    }

    /// The bar's own item ROUTES through the door too — the
    /// values it paints are the pre-#1485 ones, so
    /// `SpaceGlyphInkTests` cannot see a hand copy restored
    /// beside the door; only the spelling can.
    @Test("The bar item paints through the door, not a copy")
    func barItemRoutesThroughTheDoor() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Bar/SpaceBarItemView+Style.swift"
            )
        let style = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(count(".identifierInk(", in: style) == 1)
        #expect(count(".itemColor(for:", in: style) == 1)
        // Located by its brace-balanced body, which a retune
        // cannot lose (tests.md ▸ a negative clause); the app
        // glyphs keep their own dim ladder outside it.
        let body = try #require(
            balancedBody(after: "funcstyleIdentifier(){", in: style)
        )
        #expect(body.contains(".identifierInk("))
        for copy in [
            "dimFactor", "activeItemColor", "hoverItemColor",
            "stateColor", "untintedAlpha",
        ] {
            #expect(
                !body.contains(copy),
                Comment(rawValue: "styleIdentifier spells \(copy)")
            )
        }
    }

    private func balancedBody(
        after opener: String,
        in s: String
    ) -> String? {
        guard let start = s.range(of: opener) else { return nil }
        var depth = 1
        var i = start.upperBound
        while i < s.endIndex {
            if s[i] == "{" { depth += 1 }
            if s[i] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(s[start.upperBound..<i])
                }
            }
            i = s.index(after: i)
        }
        return nil
    }

    /// The Spaces row hands the picker the DRAFT's style, so the
    /// preview follows the palette being edited rather than a
    /// saved one.
    @Test("The Spaces row hands the picker the draft's style")
    func spacesRowHandsTheDraft() throws {
        let spaces = try squashed("Sections/SpacesSection.swift")
        #expect(
            spaces.contains(
                "preview:.spaceBar(model.config.settings.spaceBarStyle,"
            )
        )
    }
}
