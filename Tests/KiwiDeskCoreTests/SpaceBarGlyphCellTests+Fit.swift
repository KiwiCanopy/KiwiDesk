import AppKit
import Testing

@testable import KiwiDeskCore

/// The fit half of `SpaceBarGlyphCellTests` (#1529), split under
/// §2.1: a glyph whose ink would pass its cell by more than the
/// slack its site states is scaled to fit. The app site states
/// none, the identifier the item's pad; the helper converts the
/// font and re-measures once.
extension SpaceBarGlyphCellTests {
    /// The app site states no slack: an oversize ligature is
    /// fitted to the bare cell, since the next cell abuts.
    @Test("an oversize app ligature is fitted to its cell")
    func oversizeAppLigatureFitsTheCell() throws {
        let view = Self.item(horizontal: true)
        let field = try #require(view.appViews[2] as? NSTextField)
        let font = try Self.requireAppFont(field)
        #expect(font.pointSize < view.glyphSize)
        let ink = BarTextGlyph.inkBounds(field.stringValue, font: font)
        #expect(ink.width <= Self.cell + 0.01)
    }

    /// A monogram whose ink passes the pad IS fitted, and the fit
    /// keeps the system font the system font and lands inside
    /// the slack — its tracking is not linear in size, which one
    /// re-measure absorbs.
    @Test("a wide monogram is fitted within the pad as the system font")
    func wideMonogramIsFittedWithinThePad() throws {
        let view = Self.item(horizontal: true)
        view.configure(
            identity: .space(SpaceID("WW")),
            spaceGlyph: .text("WW", tinted: true),
            apps: [],
            active: true,
            horizontal: true,
            style: Self.style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
        let field = view.identifierLabel
        let font = try #require(field.font)
        let ladder = NSFont.systemFont(ofSize: view.identifierFont)
        let slack = SpaceBarItemView.pad * 2
        try #require(
            BarTextGlyph.inkBounds("WW", font: ladder).width
                > Self.cell + slack,
            "the fixture fits the pad"
        )
        #expect(font.pointSize < view.identifierFont)
        #expect(font.familyName == ladder.familyName)
        let ink = BarTextGlyph.inkBounds("WW", font: font)
        #expect(ink.width <= Self.cell + slack + 0.01)
    }

    /// A ligature that overshoots its em is scaled to the cell,
    /// so along the bar no glyph reaches its neighbour's cell.
    @Test("every bundled ligature's ink fits the floor's cell")
    func everyLigatureFitsTheCell() throws {
        let map = try #require(AppFontGlyphMap.loadBundled())
        let ligatures = Set(map.values)
        try #require(ligatures.count > 100)
        let size = Self.style.glyphFontSize(forDepth: Self.depth)
        let cell = CGRect(x: 0, y: 0, width: Self.cell, height: Self.cell)
        var scaled = 0
        for ligature in ligatures {
            let field = NSTextField(labelWithString: ligature)
            field.alignment = .center
            field.font = try #require(AppFont.font(size: size))
            field.frame = BarTextGlyph.frame(for: field, in: cell)
            let font = try Self.requireAppFont(field)
            let ink = BarTextGlyph.inkBounds(ligature, font: font)
            #expect(ink.width <= Self.cell + 0.01, "\(ligature)")
            if font.pointSize < size { scaled += 1 }
        }
        // The clause is live: the bundled font has ligatures the
        // fit had to scale.
        #expect(scaled > 0)
    }

    /// The identifier states the item's pad as its slack: a
    /// three-digit id keeps the ladder's size beside a one-digit
    /// neighbour and reaches into the pad, never past it.
    @Test("a three-digit identifier keeps its size and stays in the pad")
    func identifierKeepsTheLadderSize() throws {
        let view = Self.item(horizontal: true)
        view.configure(
            identity: .space(SpaceID("100")),
            spaceGlyph: .text("100", tinted: true),
            apps: [],
            active: true,
            horizontal: true,
            style: Self.style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
        let field = view.identifierLabel
        let font = try #require(field.font)
        #expect(font.pointSize == view.identifierFont)
        let ink = BarTextGlyph.inkBounds("100", font: font)
        try #require(ink.width > Self.cell, "the fixture fits the cell")
        #expect(ink.width <= Self.cell + SpaceBarItemView.pad * 2)
        let span = try #require(Self.inkSpan(of: field))
        #expect(
            span.lowerBound > 0 && span.upperBound < field.bounds.width,
            "ink \(span) touches the field's edge"
        )
    }
}
