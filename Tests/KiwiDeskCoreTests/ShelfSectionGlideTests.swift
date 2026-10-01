import AppKit
import Testing

@testable import KiwiDeskCore

/// A section already on the shelf glides to its new slot from where
/// its content was DRAWN (#1838): the section re-lays its content
/// for the new slot at once, so a glide from its old frame drew
/// that content aside on the first frame and slid it back — the
/// Space Bar jumping as an App Bar joined the shelf, measured on
/// device.
@Suite("Shelf section glide")
struct ShelfSectionGlideTests {
    /// The Space Bar lone across a 1728 pt edge, content centred,
    /// then fused into a 455 pt slot at 444.5, content at its end.
    @Test("The glide starts where the content was drawn")
    func startsAtTheDrawnContent() {
        let lone = CGRect(x: 0, y: 0, width: 1728, height: 40)
        let drawnLone = CGRect(x: 636, y: 0, width: 440, height: 40)
        let slot = CGRect(x: 444.5, y: 0, width: 455, height: 40)
        let contentInSlot = CGRect(x: 10, y: 0, width: 440, height: 40)
        let start = ShelfOverlay.glideStart(
            from: lone,
            drawn: drawnLone,
            content: contentInSlot,
            to: slot,
            horizontal: true
        )
        // The content sits on screen where it was drawn…
        #expect(start.minX + contentInSlot.minX == lone.minX + drawnLone.minX)
        // …at the new size, so only the origin travels.
        #expect(start.size == slot.size)
    }

    /// Between two Spaces with an App Bar the section keeps its
    /// content at the same offset and only its length changes.
    @Test("Content keeping its offset glides from the old frame")
    func sameOffsetGlidesSizeToo() {
        let from = CGRect(x: 820, y: 0, width: 681, height: 40)
        let start = ShelfOverlay.glideStart(
            from: from,
            drawn: CGRect(x: 21, y: 0, width: 623, height: 40),
            content: CGRect(x: 21.3, y: 0, width: 300, height: 40),
            to: CGRect(x: 900, y: 0, width: 340, height: 40),
            horizontal: true
        )
        // The old frame, size included: the new row is revealed as
        // the section grows, cropped as it shrinks.
        #expect(start == from)
    }

    /// A lone section's slot is the whole strip on every Space;
    /// its row re-centring inside it moved the section (device).
    @Test("An unchanged slot never moves the section")
    func unchangedSlotStays() {
        let strip = CGRect(x: 0, y: 0, width: 1728, height: 40)
        let start = ShelfOverlay.glideStart(
            from: strip,
            drawn: CGRect(x: 400, y: 0, width: 900, height: 40),
            content: CGRect(x: 644, y: 0, width: 440, height: 40),
            to: strip,
            horizontal: true
        )
        #expect(start == strip)
    }

    @Test("A vertical shelf holds its content along y")
    func verticalHoldsY() {
        let start = ShelfOverlay.glideStart(
            from: CGRect(x: 0, y: 100, width: 40, height: 800),
            drawn: CGRect(x: 0, y: 300, width: 40, height: 200),
            content: CGRect(x: 0, y: 20, width: 40, height: 200),
            to: CGRect(x: 0, y: 500, width: 40, height: 240),
            horizontal: false
        )
        #expect(start.minY + 20 == CGFloat(100 + 300))
        #expect(start.minX == 0)
        #expect(start.size == CGSize(width: 40, height: 240))
    }

    @Test("No content reading glides from the old frame")
    func zeroContentKeepsOldFrame() {
        let from = CGRect(x: 7, y: 0, width: 300, height: 40)
        #expect(
            ShelfOverlay.glideStart(
                from: from,
                drawn: .zero,
                content: CGRect(x: 1, y: 0, width: 2, height: 40),
                to: CGRect(x: 90, y: 0, width: 200, height: 40),
                horizontal: true
            ) == from
        )
    }
}

/// A frame collapsed to an anchor (#1838): what a section joining
/// a fused shelf grows from and a leaving one shrinks to, at the
/// end facing the section it joins or leaves.
@Suite("Shelf frame collapses to its anchor")
struct ShelfAppearAnchorTests {
    private let plate = CGRect(x: 100, y: 0, width: 400, height: 40)

    @Test(
        "The collapsed plate sits at the anchor",
        arguments: [
            (KiwiShelf.Alignment.start, CGFloat(100)),
            (.center, 300),
            (.end, 500),
        ]
    )
    func collapsesToTheAnchor(alignment: KiwiShelf.Alignment, x: CGFloat) {
        let collapsed = ShelfOverlay.collapsed(
            plate,
            to: alignment,
            horizontal: true
        )
        #expect(collapsed.width == 0)
        #expect(collapsed.minX == x)
        #expect(collapsed.height == plate.height)
    }

    @Test("A vertical shelf collapses along y")
    func verticalCollapse() {
        let collapsed = ShelfOverlay.collapsed(
            CGRect(x: 0, y: 100, width: 40, height: 400),
            to: .center,
            horizontal: false
        )
        #expect(collapsed.height == 0)
        #expect(collapsed.minY == 300)
        #expect(collapsed.width == 40)
    }
}
