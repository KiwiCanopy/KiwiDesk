import AppKit
import Testing

@testable import KiwiDeskCore

/// The hidden shelf's handles paint their Fill BEHIND their glass
/// (#2569 ▸ owner, 2026-10-24): the panel never wears the key-window
/// look, and glass over a Fill on top draws its edge as a border.
/// Every other glass keeps the Fill on top (`GlassFillOnTopTests`).
@Suite("Handles paint the Fill behind the glass (#2569)", .serialized)
@MainActor
struct ShelfHandleFillBehindTests {
    @Test(
        "the Fill is the glass's sibling beneath, coloured",
        arguments: [
            false, true,
        ]
    )
    func fillSitsBehind(hovered: Bool) throws {
        let before = LiquidGlassGate.override
        LiquidGlassGate.override = { false }
        defer { LiquidGlassGate.override = before }
        var spec = ShelfHandleSpec(
            mark: .line,
            frame: CGRect(x: 100, y: 0, width: 36, height: 8),
            edge: .top,
            fill: GlassFill(hex: "#1A1A2EA5"),
            currentInk: "#000000",
            ink: "#AAAAAA",
            emptyInk: "#555555",
            highlight: "#FF0000",
            shown: false,
            hovered: hovered,
            reveal: .slide,
            rimWidth: 3
        )
        spec.glass = true
        let view = ShelfHandleView()
        view.frame = CGRect(
            origin: .zero,
            size: ShelfHandle.room(of: spec).size
        )
        view.render(spec, animated: false)
        let box = try #require(view.glass, "no glass below macOS 26")
        let host = try #require(GlassBox.host(of: box.glass))
        guard #available(macOS 26, *) else { return }
        let glass = try #require(box.glass as? NSGlassEffectView)
        #expect(!(glass.contentView is GlassBackdrop))
        let below = host.subviews.firstIndex(of: box.tint)
        let above = host.subviews.firstIndex(of: glass)
        #expect(below.map { $0 + 1 } == above)
        #expect(box.tint.frame == glass.frame)
        #expect(box.tint.gradient?.colors?.count == 2)
    }
}
