import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Bars preview draws the draft's highlight width (#1680):
/// both bars' specs carry the width at the frame's scale, and the
/// edge mark is Core's derivation, not a copy of its ratio.
@Suite("Highlight width in the Bars preview")
@MainActor
struct HighlightWidthPreviewTests {
    private static let scale: CGFloat = 1.8

    private static func tile(width: CGFloat) -> HomeCardBarsTile {
        var settings = TilingSettings()
        settings.kiwishelf.highlightWidth = width
        return HomeCardBarsTile(settings: settings, scale: scale)
    }

    @Test("Both bars' specs follow the draft width", arguments: [2.0, 5.0])
    func specsFollowWidth(width: CGFloat) {
        let tile = Self.tile(width: width)
        let unit = HomeCardBarsTile.indicatorPerPoint * Self.scale
        let shelf = tile.settings.kiwishelf
        let specs = [
            tile.spaceSpec(tile.settings.spaceBarLook),
            tile.appSpec(
                tile.settings.appBarLook(
                    for: tile.settings.appBarHosts[0]
                ),
                vertical: false
            ),
        ]
        for spec in specs {
            #expect(spec.outlineWidth == max(1, width * unit))
            #expect(spec.edgeMarkWidth == shelf.edgeMarkThickness * unit)
        }
    }

    @Test("A wider highlight draws a wider mark")
    func widerIsWider() {
        let thin = Self.tile(width: 2)
        let wide = Self.tile(width: 5)
        let a = thin.spaceSpec(thin.settings.spaceBarLook)
        let b = wide.spaceSpec(wide.settings.spaceBarLook)
        #expect(b.outlineWidth > a.outlineWidth)
        #expect(b.edgeMarkWidth > a.edgeMarkWidth)
    }
}
