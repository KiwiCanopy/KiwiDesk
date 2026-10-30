import AppKit
import Testing

@testable import KiwiDeskCore

/// The pocket is the bare mark under every shelf style (#2776): it
/// lights by a two-tone edge and lifts when hovered, never a box; its
/// handle shows the kiwis alone; and while a window drag runs it
/// stands above the drag's ghost, which shares the bars' level.
@Suite("Pocket bare mark (#2776)", .serialized)
@MainActor
struct PocketBareMarkTests {
    private func pocket() -> BriefPocketView {
        let view = BriefPocketView(
            frame: CGRect(x: 0, y: 0, width: 32, height: 32)
        )
        view.wear(markHex: "")
        view.layoutSubtreeIfNeeded()
        return view
    }

    @Test("the pocket lights by a two-tone edge and lifts when hovered")
    func lightsByTheEdge() {
        let view = pocket()
        view.setLook(.lit)
        #expect(view.edgeOpacity == BriefPocketView.lineOpacity)
        #expect(view.liftScale == BriefPocketView.lift)
        // A window just in or out keeps the edge, never the lift.
        view.setLook(.active)
        #expect(view.edgeOpacity == BriefPocketView.lineOpacity)
        #expect(view.liftScale == 1)
        view.setLook(.rest)
        #expect(view.edgeOpacity == 0)
        #expect(view.liftScale == 1)
    }

    /// The pixel at grid point `at` of `image` drawn at 2x.
    private func alpha(
        of image: NSImage,
        at point: (x: Int, y: Int)
    ) throws -> CGFloat {
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 48,
                pixelsHigh: 48,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        rep.size = NSSize(width: 24, height: 24)
        let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: 24, height: 24))
        NSGraphicsContext.restoreGraphicsState()
        let color = try #require(
            rep.colorAt(x: point.x * 2, y: point.y * 2)
        )
        return color.alphaComponent
    }

    @Test("the handle's kiwis come without the bag")
    func handleShowsKiwisAlone() throws {
        // (12, 15) is inside the bag, clear of the slices.
        let kiwis = PocketMark.kiwis.image(size: 24, hex: "")
        #expect(try alpha(of: kiwis, at: (12, 15)) < 0.5)
        #expect(try alpha(of: kiwis, at: (8, 7)) > 0.5)
        // Control: the full mark draws the bag there.
        let mark = PocketMark.mark.image(size: 24, hex: "")
        #expect(try alpha(of: mark, at: (12, 15)) > 0.5)
    }

    @Test("the section stands a level above its shelf and any ghost")
    func sectionStandsAboveTheShelf() throws {
        let overlay = ShelfOverlay()
        let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)
        let slot = CGRect(x: 1060, y: 300, width: 40, height: 40)
        let plate = CGRect(x: 0, y: 0, width: 300, height: 40)
        overlay.show(
            strip: strip,
            edge: .top,
            shelf: KiwiShelf(),
            sheen: 0,
            sections: [
                .init(
                    view: NSView(),
                    slot: strip,
                    plate: plate,
                    content: plate
                )
            ],
            pocket: ShelfPocketPiece.Mount(view: NSView(), slot: slot)
        )
        // A click fronts the shelf's panel within its level, so only
        // a higher level keeps the pocket over it (#2776).
        let panel = try #require(overlay.pocket.panel)
        let shelf = try #require(overlay.panel)
        #expect(panel.level == BarPanel.aboveLevel)
        #expect(panel.level > shelf.level)
        overlay.hide()
    }
}
