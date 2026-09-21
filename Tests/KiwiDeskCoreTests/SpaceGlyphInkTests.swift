import AppKit
import Testing

@testable import KiwiDeskCore

/// A Space item's identifier ink has ONE home,
/// `SpaceBarStyle.identifierInk` (#1485, #702): a tinted glyph
/// takes the state's item colour at full strength, an untinted
/// one keeps its own colours and is dimmed only at rest. The
/// bar draws the verdict and the icon picker's preview reads it,
/// so the two cannot disagree about what lands on the plate.
@Suite("Space identifier ink")
struct SpaceGlyphInkTests {
    private var style: SpaceBarStyle {
        var style = SpaceBarStyle()
        style.itemColor = "#111111"
        style.hoverItemColor = "#222222"
        style.activeItemColor = "#333333"
        style.dimFactor = 0.42
        return style
    }

    @Test("A tinted glyph takes the state's colour at full strength")
    func tintedGlyphTakesTheStateColour() {
        let style = self.style
        let glyphs: [SpaceGlyph] = [
            .symbol("book"), .text("4", tinted: true),
        ]
        for glyph in glyphs {
            #expect(
                style.identifierInk(of: glyph, state: .resting)
                    == SpaceGlyphInk(hex: "#111111", alpha: 1)
            )
            #expect(
                style.identifierInk(of: glyph, state: .hovered)
                    == SpaceGlyphInk(hex: "#222222", alpha: 1)
            )
            #expect(
                style.identifierInk(of: glyph, state: .active)
                    == SpaceGlyphInk(hex: "#333333", alpha: 1)
            )
        }
    }

    @Test("An untinted glyph keeps its colours, dimmed only at rest")
    func untintedGlyphIsDimmedNotTinted() {
        let style = self.style
        let emoji = SpaceGlyph.text("⭐", tinted: false)
        #expect(
            style.identifierInk(of: emoji, state: .resting)
                == SpaceGlyphInk(hex: nil, alpha: 0.42)
        )
        #expect(
            style.identifierInk(of: emoji, state: .hovered)
                == SpaceGlyphInk(hex: nil, alpha: 1)
        )
        #expect(
            style.identifierInk(of: emoji, state: .active)
                == SpaceGlyphInk(hex: nil, alpha: 1)
        )
    }

    /// The bar's item PAINTS the verdict — the consumer, not
    /// only the type (the #1485 review's ask): a resting Space
    /// item, an active one, and the layer item, which is active
    /// by ruling (#1169).
    @Test("The item view paints the door's verdict")
    @MainActor
    func itemViewPaintsTheVerdict() throws {
        let style = self.style
        let emoji = SpaceGlyph.text("⭐", tinted: false)
        let space = SpaceBarItemView.Identity.space(SpaceID("1"))
        let resting = Self.item(
            emoji,
            identity: space,
            active: false,
            style: style
        )
        #expect(resting.identifierLabel.alphaValue == 0.42)
        #expect(resting.identifierLabel.textColor == .labelColor)
        let active = Self.item(
            emoji,
            identity: space,
            active: true,
            style: style
        )
        #expect(active.identifierLabel.alphaValue == 1)
        let layer = Self.item(
            emoji,
            identity: .layer("work"),
            active: false,
            style: style
        )
        #expect(layer.identifierLabel.alphaValue == 1)
        let symbol = Self.item(
            .symbol("book"),
            identity: space,
            active: false,
            style: style
        )
        let tint = try #require(symbol.identifierImage.contentTintColor)
        #expect(tint == NSColor(kiwiHex: "#111111"))
        #expect(symbol.identifierImage.alphaValue == 1)
    }

    @MainActor
    private static func item(
        _ glyph: SpaceGlyph,
        identity: SpaceBarItemView.Identity,
        active: Bool,
        style: SpaceBarStyle
    ) -> SpaceBarItemView {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 40, height: 40)
        )
        view.configure(
            identity: identity,
            spaceGlyph: glyph,
            apps: [],
            active: active,
            horizontal: true,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        return view
    }
}
