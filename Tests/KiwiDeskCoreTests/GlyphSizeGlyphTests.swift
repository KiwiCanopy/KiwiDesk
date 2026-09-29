import AppKit
import Testing

@testable import KiwiDeskCore

/// Glyph size reaches the Space Bar's TEXT glyphs and the
/// front-app segment's measure (#1682): App Font glyphs in the
/// items and the segment draw at the content depth's glyph size,
/// and the segment's measured extent is what its title draws.
@Suite("Glyph size reaches the Space Bar's glyphs", .serialized)
@MainActor
struct GlyphSizeGlyphTests {
    private static let depth: CGFloat = 40
    private static let content: CGFloat = 28
    private static let glyph = ":safari:"

    init() { LiquidGlassGate.override = { false } }

    private static func look(glyphSize: CGFloat) -> SpaceBarLook {
        var look = SpaceBarLook()
        look.glyphSize = glyphSize
        look.liquidGlass = false
        look.backgroundStyle = .plain
        look.showFrontApp = true
        return look
    }

    private static func app(_ name: String) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: name,
            title: "A window",
            icon: nil,
            glyph: glyph,
            focused: false,
            count: 1
        )
    }

    private func overlay(
        glyphSize: CGFloat,
        in manager: SpaceBarManager
    ) throws -> SpaceBarOverlay {
        manager.sync([
            SpaceBarManager.Bar(
                display: barTitleDisplay,
                items: [
                    SpaceBarOverlay.Item(
                        space: SpaceID("1"),
                        spaceGlyph: .text("1", tinted: true),
                        apps: [Self.app("A")],
                        active: true,
                        after: .none
                    )
                ],
                frontApp: Self.app("Front"),
                frontWindow: WindowID(1),
                strip: CGRect(x: 0, y: 0, width: 1440, height: Self.depth),
                style: Self.look(glyphSize: glyphSize),
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        ])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    private func glyphSizes(
        glyphSize: CGFloat
    ) throws -> (item: CGFloat, front: CGFloat) {
        let manager = SpaceBarManager()
        let overlay = try overlay(glyphSize: glyphSize, in: manager)
        let view = try #require(overlay.itemViews.first)
        view.layoutSubtreeIfNeeded()
        let field = try #require(view.appViews.first as? NSTextField)
        #expect(!overlay.frontGlyph.isHidden)
        return (
            try #require(field.font?.pointSize),
            try #require(overlay.frontGlyph.font?.pointSize)
        )
    }

    @Test("Item and front-app glyphs draw at the content depth")
    func glyphsFollowContent() throws {
        let plain = try glyphSizes(glyphSize: 0)
        let padded = try glyphSizes(glyphSize: 28)
        let size = Self.look(glyphSize: 28)
            .glyphFontSize(forContentDepth: Self.content)
        #expect(padded.item == size)
        #expect(padded.front == size)
        #expect(padded.item < plain.item)
        #expect(padded.front < plain.front)
    }

    /// The segment's measure lays its title out at the font the
    /// title draws, so the run's length is what is drawn.
    @Test("The front-app segment measures the title it draws")
    func frontExtentMeasuresTheDrawnTitle() throws {
        let manager = SpaceBarManager()
        let overlay = try overlay(glyphSize: 28, in: manager)
        let look = Self.look(glyphSize: 28)
        let drawn = try #require(overlay.frontName.font)
        #expect(
            drawn.pointSize
                == look.titleFontSize(forContentDepth: Self.content)
        )
        let extent = overlay.frontExtent(
            Self.app("Front"),
            depth: Self.depth,
            horizontal: true,
            style: look
        )
        let pad = SpaceBarItemView.pad
        let cell = SpaceBarItemView.cell(contentDepth: Self.content)
        let fixed =
            look.itemGap + BarDivider.sectionThickness + look.itemGap
            + cell + pad + pad
        let title = ceil(
            ("A window" as NSString).size(
                withAttributes: [.font: drawn]
            ).width
        )
        #expect(extent - fixed == title)
    }
}
