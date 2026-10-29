import AppKit
import Testing

@testable import KiwiDeskCore

/// The pocket off a bar's edge is the bare mark (#2776): it lights by
/// its ink and a soft edge, never a box; its handle shows the kiwis
/// alone; and while a window drag runs it stands above the drag's
/// ghost, which shares the bars' level.
@Suite("Pocket bare mark (#2776)", .serialized)
@MainActor
struct PocketBareMarkTests {
    private func pocket(platePiece: Bool) -> BriefPocketView {
        let view = BriefPocketView(
            frame: CGRect(x: 0, y: 0, width: 32, height: 32)
        )
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        view.wear(shelf, markHex: "", platePiece: platePiece)
        view.setLook(.lit)
        view.layoutSubtreeIfNeeded()
        return view
    }

    @Test("a bare pocket lights with no box and wears its edge")
    func bareLightsWithoutABox() {
        let bare = pocket(platePiece: false)
        #expect(!bare.drawsLitBox)
        #expect(bare.edgeOpacity == 1)
        // A window just in keeps it; at rest it goes (owner, #2776).
        bare.setLook(.active)
        #expect(bare.edgeOpacity == 1)
        bare.setLook(.rest)
        #expect(bare.edgeOpacity == 0)
        // Control: a plated section keeps its hover box, no edge.
        let plated = pocket(platePiece: true)
        #expect(plated.drawsLitBox)
        #expect(plated.edgeOpacity == 0)
    }

    @Test("the pocket wears a box only as a Boxed shelf's section")
    func plateOnlyOnABar() {
        var shelf = KiwiShelf()
        shelf.backgroundStyle = .boxed
        let slot = CGRect(x: 0, y: 0, width: 40, height: 40)
        #expect(KiwiCore.pocketWearsPlate(slot: slot, shelf: shelf))
        #expect(!KiwiCore.pocketWearsPlate(slot: nil, shelf: shelf))
        // Plain: bare at a hugging shelf's corner and on a full plate.
        shelf.backgroundStyle = .plain
        for fit in [KiwiShelf.BackgroundFit.hug, .full] {
            shelf.backgroundFit = fit
            #expect(!KiwiCore.pocketWearsPlate(slot: slot, shelf: shelf))
        }
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

    @Test("a dragged window finds the section above its ghost")
    func sectionRisesForADrag() throws {
        let overlay = ShelfOverlay()
        let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)
        let slot = CGRect(x: 1060, y: 300, width: 40, height: 40)
        let plate = CGRect(x: 0, y: 0, width: 300, height: 40)
        let view = NSView()
        let show = { (raised: Bool) in
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
                pocket: ShelfPocketPiece.Mount(
                    view: view,
                    slot: slot,
                    raised: raised
                )
            )
        }
        show(true)
        let panel = try #require(overlay.pocket.panel)
        #expect(panel.level == BarPanel.aboveLevel)
        show(false)
        #expect(panel.level == BarPanel.level)
        overlay.hide()
    }
}
