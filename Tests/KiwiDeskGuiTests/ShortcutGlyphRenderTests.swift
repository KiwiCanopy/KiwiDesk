import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A row's glyph slot holds its frame whatever it draws (#3267 ▸
/// Ruling 2): every emoji the picker offers, and the ZWJ sequences
/// a user can paste, draws no wider than the symbol's square, and
/// the view lays out at that square for an emoji and a symbol alike.
/// Main actor: one hosting view per emoji per side, a few dozen.
@Suite("Shortcut glyph render (#3267)")
@MainActor
struct ShortcutGlyphRenderTests {
    /// The picker's emoji plus the ZWJ sequences a user can paste.
    private static var emoji: [String] {
        IconCatalog.emoji.map(\.glyph) + [
            "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}",
            "\u{1F3F3}\u{FE0F}\u{200D}\u{1F308}", "\u{1FAE8}",
        ]
    }

    private static let sides = [
        ShortcutGlyphView.rowSide, ShortcutLayerChip.iconSide,
    ]

    private func hosted(_ view: some View) -> CGSize {
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// The glyph as the view draws it inside its frame.
    private func drawn(_ glyph: ShortcutGlyph, side: CGFloat) -> CGSize {
        hosted(ShortcutGlyphView(glyph: glyph, side: side).mark)
    }

    @Test("the widest emoji the view draws fits the symbol's square")
    func widestEmojiFits() throws {
        for side in Self.sides {
            let widths = Self.emoji.map { drawn(.emoji($0), side: side) }
            let widest = try #require(widths.map(\.width).max())
            #expect(widest <= side, "side \(side): \(widest)")
            // Not shrunk past legibility: the widest fills the square.
            #expect(widest >= side * 0.8, "side \(side): \(widest)")
            let tallest = try #require(widths.map(\.height).max())
            #expect(tallest <= side, "side \(side): \(tallest)")
        }
    }

    @Test("an emoji and a symbol lay out at the same square")
    func frameIsPinned() {
        for side in Self.sides {
            let square = CGSize(width: side, height: side)
            for glyph in Self.emoji.map(ShortcutGlyph.emoji) + [
                .symbol("square.3.layers.3d")
            ] {
                #expect(
                    hosted(ShortcutGlyphView(glyph: glyph, side: side))
                        == square
                )
            }
        }
    }

    @Test("a stored icon is classified once, symbol or emoji")
    func storedIconsClassify() {
        #expect(ShortcutGlyph(icon: "star") == .symbol("star"))
        #expect(ShortcutGlyph(icon: "🎮") == .emoji("🎮"))
        #expect(ShortcutGlyph(icon: "") == nil)
        #expect(ShortcutGlyph(icon: nil) == nil)
    }

    @Test("a chip with an icon draws it and keeps the plain height")
    func chipHeightHolds() {
        func size(_ icon: ShortcutGlyph?) -> CGSize {
            hosted(
                ShortcutLayerChip(
                    name: "Gaming",
                    icon: icon,
                    selected: false,
                    action: {}
                )
            )
        }
        let plain = size(nil)
        for glyph in Self.emoji.map(ShortcutGlyph.emoji) + [
            .symbol("gamecontroller")
        ] {
            let drawn = size(glyph)
            #expect(drawn.height == plain.height, "\(glyph)")
            // The icon takes its square and a gap before the name.
            #expect(
                drawn.width >= plain.width + ShortcutLayerChip.iconSide,
                "\(glyph)"
            )
        }
    }
}
