import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A row's glyph slot holds its frame whatever it draws (#3267 ▸
/// Ruling 2): the widest emoji fits the symbol's square at the size
/// the view draws it, and the view lays out at that square for an
/// emoji and a symbol alike, so the label column never shifts.
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

    private func drawnWidth(_ emoji: String, side: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: ShortcutGlyphView.emojiSize(side: side)
        )
        return (emoji as NSString).size(withAttributes: [.font: font])
            .width
    }

    private func laidOut(_ glyph: ShortcutGlyph, side: CGFloat) -> CGSize {
        let host = NSHostingView(
            rootView: ShortcutGlyphView(glyph: glyph, side: side)
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    @Test("the widest emoji fits the symbol's square")
    func widestEmojiFits() throws {
        for side in Self.sides {
            let widest = try #require(
                Self.emoji.map { drawnWidth($0, side: side) }.max()
            )
            #expect(widest <= side, "side \(side): \(widest)")
            // Not shrunk past legibility: the widest fills the square.
            #expect(widest >= side * 0.8, "side \(side): \(widest)")
        }
    }

    @Test("an emoji and a symbol lay out at the same square")
    func frameIsPinned() throws {
        let widest = try #require(
            Self.emoji.max {
                drawnWidth($0, side: 16) < drawnWidth($1, side: 16)
            }
        )
        for side in Self.sides {
            let square = CGSize(width: side, height: side)
            #expect(laidOut(.emoji(widest), side: side) == square)
            #expect(
                laidOut(.symbol("square.3.layers.3d"), side: side)
                    == square
            )
        }
    }

    @Test("a stored icon is classified once, symbol or emoji")
    func storedIconsClassify() {
        #expect(ShortcutGlyph(icon: "star") == .symbol("star"))
        #expect(ShortcutGlyph(icon: "🎮") == .emoji("🎮"))
        #expect(ShortcutGlyph(icon: "") == nil)
        #expect(ShortcutGlyph(icon: nil) == nil)
    }

    @Test("a chip with an icon keeps the plain chip's height")
    func chipHeightHolds() {
        func height(_ icon: ShortcutGlyph?) -> CGFloat {
            let host = NSHostingView(
                rootView: ShortcutLayerChip(
                    name: "Gaming",
                    icon: icon,
                    selected: false,
                    action: {}
                )
            )
            host.layoutSubtreeIfNeeded()
            return host.fittingSize.height
        }
        let plain = height(nil)
        #expect(height(.emoji(Self.emoji.last ?? "")) == plain)
        #expect(height(.symbol("gamecontroller")) == plain)
    }
}
