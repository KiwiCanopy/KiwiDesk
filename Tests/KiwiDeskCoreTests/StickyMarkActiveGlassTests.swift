import AppKit
import Testing

@testable import KiwiDeskCore

/// The window mark (#2831): its glass wears the key-window rim
/// whenever it draws glass, from the panel's first show on, and
/// every mark — the pocket's included — sits at the same inset
/// corner of its window.
@Suite("Window mark glass and corner (#2831)")
@MainActor
struct StickyMarkActiveGlassTests {
    private let frame = CGRect(x: 200, y: 200, width: 900, height: 600)

    private func overlay(
        glass: Bool,
        glyphs: [StickyMarkManager.Glyph]
    ) -> StickyMarkOverlay {
        let overlay = StickyMarkOverlay(window: 1) { _, _ in false }
        overlay.readReduceMotion = { false }
        // The manager's order: glass and glyphs before the first
        // update builds the panel.
        overlay.setGlass(glass)
        overlay.setGlyphs(glyphs)
        overlay.update(frame: frame)
        return overlay
    }

    private var sticky: StickyMarkManager.Glyph {
        .sticky(StickyStyle.symbolName, color: "")
    }

    @Test("the mark's panel wears the rim while it draws glass")
    func rimFollowsGlass() throws {
        guard #available(macOS 26, *) else { return }
        let glassy = overlay(glass: true, glyphs: [sticky])
        defer { glassy.hide() }
        let panel = try #require(
            glassy.panelForTest as? ActiveGlassPanel
        )
        #expect(panel.wearsActiveLook)
        glassy.setGlass(false)
        #expect(!panel.wearsActiveLook, "the flat badge drops the rim")
        let flat = overlay(glass: false, glyphs: [sticky])
        defer { flat.hide() }
        let flatPanel = try #require(
            flat.panelForTest as? ActiveGlassPanel
        )
        #expect(!flatPanel.wearsActiveLook)
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
