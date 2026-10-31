import AppKit
import Testing

@testable import KiwiDeskCore

/// Every window mark — the pocket's included — sits at the same
/// inset corner of its window (#2831 part 4).
@Suite("Window mark corner (#2831)")
@MainActor
struct StickyMarkCornerTests {
    private let frame = CGRect(x: 200, y: 200, width: 900, height: 600)

    private func overlay(
        glass: Bool,
        glyphs: [StickyMarkManager.Glyph]
    ) -> StickyMarkOverlay {
        let overlay = StickyMarkOverlay(window: 1) { _, _ in false }
        overlay.readReduceMotion = { false }
        // The manager's order: glass and glyphs, then the update.
        overlay.setGlass(glass)
        overlay.setGlyphs(glyphs)
        overlay.update(frame: frame)
        return overlay
    }

    private var sticky: StickyMarkManager.Glyph {
        .sticky(StickyStyle.symbolName, color: "")
    }

    @Test("the pocket mark sits at the sticky mark's corner")
    func pocketTakesTheInsetCorner() throws {
        let pinned = overlay(glass: false, glyphs: [sticky])
        defer { pinned.hide() }
        let pocket = overlay(glass: false, glyphs: [.pocket(color: "")])
        defer { pocket.hide() }
        let a = try #require(pinned.panelFrameForTest)
        let b = try #require(pocket.panelFrameForTest)
        #expect(a.maxX == b.maxX)
        #expect(a.maxY == b.maxY)
    }
}
