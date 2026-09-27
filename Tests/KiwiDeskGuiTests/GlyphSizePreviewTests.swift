import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Bars preview draws the draft's glyph size (#1713): both
/// bars' specs carry Core's content share and size their glyphs
/// from the content it leaves, never the full thickness.
@Suite("Glyph size in the Bars preview")
@MainActor
struct GlyphSizePreviewTests {
    private static let scale: CGFloat = 1.8

    private static func tile(glyphSize: CGFloat) -> HomeCardBarsTile {
        var settings = TilingSettings()
        settings.kiwishelf.thickness = 40
        settings.kiwishelf.glyphSize = glyphSize
        return HomeCardBarsTile(settings: settings, scale: scale)
    }

    private static func specs(
        _ tile: HomeCardBarsTile
    ) -> [HomeCardBarsTile.BarSpec] {
        [
            tile.spaceSpec(tile.settings.spaceBarLook),
            tile.appSpec(
                tile.settings.appBarLook(
                    for: tile.settings.appBarHosts[0]
                ),
                vertical: false
            ),
        ]
    }

    @Test("An automatic glyph size draws the full thickness")
    func defaultIsFull() {
        for spec in Self.specs(Self.tile(glyphSize: 0)) {
            #expect(spec.contentShare == 1)
        }
    }

    @Test("The share is Core's content depth over the thickness")
    func shareIsCores() {
        let tile = Self.tile(glyphSize: 28)
        let shelf = tile.settings.kiwishelf
        let share = shelf.contentDepth(forDepth: 40) / 40
        // Pinned, not only read back: a wrong Core formula would
        // agree with itself here (guard-prover, #1713).
        #expect(share == CGFloat(28) / 40)
        for spec in Self.specs(tile) {
            #expect(spec.contentShare == share)
        }
    }

    /// The strip's pips are content: they shrink by the share.
    @Test("A smaller glyph size draws shorter pips")
    func pipsShrink() {
        func pips(_ glyphSize: CGFloat) -> [CGFloat] {
            Self.specs(Self.tile(glyphSize: glyphSize)).map {
                BarStripView(
                    spec: $0,
                    edge: .top,
                    vertical: false,
                    scale: Self.scale
                ).pipCross
            }
        }
        for (plain, padded) in zip(pips(0), pips(28)) {
            #expect(padded < plain)
            #expect(
                abs(padded - plain * (28.0 / 40.0)) < 0.001
            )
        }
    }

    @Test("A padded shelf draws smaller glyphs")
    func paddedIsSmaller() {
        let plain = Self.specs(Self.tile(glyphSize: 0))
        let padded = Self.specs(Self.tile(glyphSize: 28))
        for (a, b) in zip(plain, padded) {
            #expect(b.fontSize < a.fontSize)
            #expect(b.thickness == a.thickness)
        }
    }
}
