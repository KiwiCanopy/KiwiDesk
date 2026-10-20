import AppKit
import Testing

@testable import KiwiDeskCore

/// The shelf panel takes the mouse wherever it lies, so it covers
/// what the shelf draws and never the rest of the strip (#2497): a
/// click beside the plate reaches the window under it. A glide or
/// a reveal opens it to the strip and its landing shrinks it back.
@Suite("Shelf panel room (#2497)", .serialized)
@MainActor
struct ShelfPanelRoomTests {
    /// Clear of the menu bar, which AppKit keeps a panel below.
    private static let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)

    private static func shelf(_ style: KiwiShelf.BackgroundStyle) -> KiwiShelf
    {
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.backgroundStyle = style
        shelf.backgroundFit = .hug
        return shelf
    }

    /// A section over the whole strip whose run asks for `plate`,
    /// in the section's own coordinates.
    private static func section(
        _ view: NSView = NSView(),
        plate: CGRect
    ) -> ShelfOverlay.Section {
        .init(view: view, slot: strip, plate: plate, content: plate)
    }

    private static func plate(at x: CGFloat) -> CGRect {
        CGRect(x: x, y: 0, width: 300, height: 40)
    }

    /// The whole strip on screen.
    private static var whole: CGRect {
        onScreen(CGRect(origin: .zero, size: strip.size))
    }

    /// `rect` in strip coordinates as the panel's Cocoa frame.
    private static func onScreen(_ rect: CGRect) -> CGRect {
        GeometryUtils.flip(
            rect.offsetBy(dx: strip.minX, dy: strip.minY),
            primaryHeight: GeometryUtils.primaryHeight
        )
    }

    private func show(
        _ overlay: ShelfOverlay,
        _ sections: [ShelfOverlay.Section],
        style: KiwiShelf.BackgroundStyle = .plain
    ) {
        overlay.show(
            strip: Self.strip,
            edge: .top,
            shelf: Self.shelf(style),
            sheen: 0,
            sections: sections
        )
    }

    @Test("The panel takes the plate, the strip staying in place")
    func panelTakesThePlate() throws {
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        show(overlay, [Self.section(plate: Self.plate(at: 200))])
        let panel = try #require(overlay.panel)
        #expect(panel.frame == Self.onScreen(Self.plate(at: 200)))
        let content = overlay.content
        let drawn = panel.convertToScreen(
            content.convert(content.bounds, to: nil)
        )
        #expect(drawn == Self.whole)
    }

    @Test("Boxed takes the span of the sections' asks")
    func boxedTakesTheAsks() throws {
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        let space = CGRect(x: 50, y: 0, width: 100, height: 40)
        let app = CGRect(x: 600, y: 0, width: 200, height: 40)
        show(
            overlay,
            [Self.section(plate: space), Self.section(plate: app)],
            style: .boxed
        )
        let panel = try #require(overlay.panel)
        #expect(
            panel.frame
                == Self.onScreen(CGRect(x: 50, y: 0, width: 750, height: 40))
        )
    }

    @Test("A glide opens the panel to the strip until it lands")
    func glideHoldsTheStrip() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        var landings: [() -> Void] = []
        overlay.afterRoomGlide = { landings.append($0) }
        let view = NSView()
        show(overlay, [Self.section(view, plate: Self.plate(at: 200))])
        let panel = try #require(overlay.panel)
        try #require(landings.isEmpty, "a first show glides nothing")
        show(overlay, [Self.section(view, plate: Self.plate(at: 600))])
        try #require(landings.count == 1)
        #expect(panel.frame == Self.whole)
        landings[0]()
        #expect(panel.frame == Self.onScreen(Self.plate(at: 600)))
    }

    @Test("A reveal opens the panel to the strip until it lands")
    func revealHoldsTheStrip() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        var landings: [() -> Void] = []
        overlay.afterReveal = { _, body in landings.append(body) }
        overlay.afterCommit = { $0() }
        overlay.slides = true
        show(overlay, [Self.section(plate: Self.plate(at: 200))])
        let panel = try #require(overlay.panel)
        try #require(landings.count == 1)
        #expect(panel.frame == Self.whole)
        landings[0]()
        #expect(panel.frame == Self.onScreen(Self.plate(at: 200)))
    }
}
