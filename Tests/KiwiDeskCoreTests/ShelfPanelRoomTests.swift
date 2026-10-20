import AppKit
import Testing

@testable import KiwiDeskCore

/// The shelf panel takes the mouse wherever it lies, so at rest it
/// covers what the shelf draws and never the rest of the strip
/// (#2497): a click beside the plate reaches the window under it,
/// while every point of the drawn plate — an overflowing run's
/// faded ends and count included — stays the shelf's. The motion
/// half is `ShelfPanelRoomMotionTests`.
@Suite("Shelf panel room (#2497)", .serialized)
@MainActor
struct ShelfPanelRoomTests {
    /// Clear of the menu bar, which AppKit keeps a panel below.
    private static let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)
    private static let side = CGRect(x: 100, y: 200, width: 40, height: 600)

    private static func shelf(_ style: KiwiShelf.BackgroundStyle) -> KiwiShelf
    {
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.backgroundStyle = style
        shelf.backgroundFit = .hug
        return shelf
    }

    /// A section over all of `strip` whose run asks for `plate`, in
    /// the section's own coordinates.
    private static func section(
        plate: CGRect,
        in strip: CGRect = strip
    ) -> ShelfOverlay.Section {
        .init(view: NSView(), slot: strip, plate: plate, content: plate)
    }

    /// `rect` in `strip`'s coordinates as a panel's Cocoa frame.
    private static func onScreen(
        _ rect: CGRect,
        in strip: CGRect = strip
    ) -> CGRect {
        GeometryUtils.flip(
            rect.offsetBy(dx: strip.minX, dy: strip.minY),
            primaryHeight: GeometryUtils.primaryHeight
        )
    }

    private func show(
        _ overlay: ShelfOverlay,
        _ sections: [ShelfOverlay.Section],
        strip: CGRect = strip,
        edge: AppBarEdge = .top,
        style: KiwiShelf.BackgroundStyle = .plain
    ) {
        overlay.show(
            strip: strip,
            edge: edge,
            shelf: Self.shelf(style),
            sheen: 0,
            sections: sections
        )
    }

    /// Where `overlay`'s content lies on screen.
    private func drawn(_ overlay: ShelfOverlay) throws -> CGRect {
        let panel = try #require(overlay.panel)
        let content = overlay.content
        return panel.convertToScreen(content.convert(content.bounds, to: nil))
    }

    @Test("A fitting run's panel takes its plate, the strip staying put")
    func panelTakesThePlate() throws {
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        let plate = CGRect(x: 200, y: 0, width: 300, height: 40)
        show(overlay, [Self.section(plate: plate)])
        let panel = try #require(overlay.panel)
        #expect(panel.frame == Self.onScreen(plate))
        let whole = CGRect(origin: .zero, size: Self.strip.size)
        #expect(try drawn(overlay) == Self.onScreen(whole))
    }

    /// An overflowing run's plate fills its segment; its fades and
    /// count lie inside it, so every press and wheel on them is
    /// still the shelf's (`ShelfOverflow`).
    @Test("An overflowing run's panel takes its whole segment")
    func overflowTakesTheSegment() throws {
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        let segment = CGRect(x: 300, y: 300, width: 500, height: 40)
        let full = CGRect(origin: .zero, size: segment.size)
        show(
            overlay,
            [
                .init(
                    view: NSView(),
                    slot: segment,
                    plate: full,
                    content: full
                )
            ]
        )
        let panel = try #require(overlay.panel)
        let inStrip = CGRect(x: 200, y: 0, width: 500, height: 40)
        #expect(panel.frame == Self.onScreen(inStrip))
        let root = try #require(panel.contentView)
        for x in [1, root.bounds.midX, root.bounds.maxX - 1] {
            #expect(root.hitTest(CGPoint(x: x, y: 20)) != nil)
        }
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
        let span = CGRect(x: 50, y: 0, width: 750, height: 40)
        #expect(panel.frame == Self.onScreen(span))
    }

    @Test("A side shelf's panel takes its plate down the edge")
    func sideShelfTakesThePlate() throws {
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        let plate = CGRect(x: 0, y: 150, width: 40, height: 200)
        show(
            overlay,
            [Self.section(plate: plate, in: Self.side)],
            strip: Self.side,
            edge: .left
        )
        let panel = try #require(overlay.panel)
        #expect(panel.frame == Self.onScreen(plate, in: Self.side))
        let whole = CGRect(origin: .zero, size: Self.side.size)
        #expect(try drawn(overlay) == Self.onScreen(whole, in: Self.side))
    }

    /// A refresh that moves nothing — a title, a focus — never
    /// opens the room it would otherwise hold for a glide.
    @Test("A repeat show with the same plate keeps the panel on it")
    func unchangedShowKeepsThePlate() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        var landings: [() -> Void] = []
        overlay.afterGlide = { landings.append($0) }
        let view = NSView()
        let plate = CGRect(x: 200, y: 0, width: 300, height: 40)
        let first = ShelfOverlay.Section(
            view: view,
            slot: Self.strip,
            plate: plate,
            content: plate
        )
        show(overlay, [first])
        let inner = plate.insetBy(dx: 10, dy: 0)
        show(
            overlay,
            [.init(view: view, slot: Self.strip, plate: plate, content: inner)]
        )
        let panel = try #require(overlay.panel)
        #expect(panel.frame == Self.onScreen(plate))
        #expect(landings.isEmpty)
    }
}
