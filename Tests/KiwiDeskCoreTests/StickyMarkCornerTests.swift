import AppKit
import Testing

@testable import KiwiDeskCore

/// The window mark (#2831): frosted glass on a panel that wears the
/// key-window rim, and every mark — the pocket's included — at the
/// same inset corner of its window.
@Suite("Window mark glass and corner (#2831)")
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

    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    private var sticky: StickyMarkManager.Glyph {
        .sticky(StickyStyle.symbolName, color: "")
    }

    @Test("the mark is frosted glass on a rimmed panel")
    func frostedWithRim() throws {
        let mark = overlay(glass: true, glyphs: [sticky])
        defer { mark.hide() }
        // The class is the guard: an `ActiveGlassPanel` answers YES
        // unless told otherwise, and nothing tells the mark's.
        _ = try #require(mark.panelForTest as? ActiveGlassPanel)
        try #require(Self.drawsGlass, "no glass below macOS 26")
        if #available(macOS 26, *) {
            let glass = try #require(
                mark.plate.glass as? NSGlassEffectView,
                "no glass hosted"
            )
            #expect(glass.style == .regular)
        }
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
