import AppKit
import Testing

@testable import KiwiDeskCore

/// **A joining or leaving section reveals its content in place from
/// the seam** (#3386): while the section's frame grows out of, or
/// shrinks back into, the section it joins, its content stays where
/// its slot lays it, whichever end of the section the seam is on, so
/// it never rolls in with the moving edge.
@Suite("Shelf joiner reveals in place (#3386)")
@MainActor
struct ShelfJoinerInPlaceTests {
    private static let strip = CGRect(x: 0, y: 0, width: 1000, height: 40)
    private static let tall = CGRect(x: 0, y: 0, width: 40, height: 1000)

    private static func section(
        _ view: NSView,
        slot: CGRect
    ) -> ShelfOverlay.Section {
        .init(
            view: view,
            slot: slot,
            plate: CGRect(origin: .zero, size: slot.size),
            content: CGRect(origin: .zero, size: slot.size)
        )
    }

    private static func shown(
        _ sections: [ShelfOverlay.Section],
        in strip: CGRect,
        edge: AppBarEdge
    ) -> ShelfOverlay {
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        let overlay = ShelfOverlay()
        overlay.show(
            strip: strip,
            edge: edge,
            shelf: shelf,
            sheen: 0,
            sections: sections
        )
        return overlay
    }

    /// Where `view`'s content origin sits on the strip.
    private static func contentOrigin(
        _ view: NSView,
        on overlay: ShelfOverlay
    ) -> CGPoint {
        view.convert(CGPoint.zero, to: overlay.stripView)
    }

    @Test(
        "A joiner's content stands at its slot, the seam at either end",
        arguments: [
            // Seam on the joiner's trailing end: it grows leftwards.
            (
                CGRect(x: 0, y: 0, width: 400, height: 40),
                CGRect(x: 400, y: 0, width: 600, height: 40)
            ),
            // Seam on its leading end: it grows rightwards.
            (
                CGRect(x: 600, y: 0, width: 400, height: 40),
                CGRect(x: 0, y: 0, width: 600, height: 40)
            ),
        ]
    )
    func joinerStandsInPlace(joinerSlot: CGRect, otherSlot: CGRect) {
        let other = Self.section(AppBarOverlay.FlippedView(), slot: otherSlot)
        let overlay = Self.shown([other], in: Self.strip, edge: .top)
        let view = AppBarOverlay.FlippedView()
        let joiner = Self.section(view, slot: joinerSlot)
        overlay.standGlideStarts(
            [joiner, other],
            in: Self.strip,
            horizontal: true
        )
        #expect(view.frame.width == 0)
        #expect(Self.contentOrigin(view, on: overlay) == joinerSlot.origin)
        overlay.place(
            [joiner, other],
            in: Self.strip,
            horizontal: true,
            animated: true
        )
        #expect(view.frame == joinerSlot)
        #expect(view.bounds.origin == .zero)
    }

    @Test("A leaver's content stays at its slot as it shrinks")
    func leaverStaysInPlace() {
        let leaverSlot = CGRect(x: 0, y: 0, width: 400, height: 40)
        let view = AppBarOverlay.FlippedView()
        let leaver = Self.section(view, slot: leaverSlot)
        let other = Self.section(
            AppBarOverlay.FlippedView(),
            slot: CGRect(x: 400, y: 0, width: 600, height: 40)
        )
        let overlay = Self.shown(
            [leaver, other],
            in: Self.strip,
            edge: .top
        )
        overlay.place(
            [other],
            in: Self.strip,
            horizontal: true,
            animated: true
        )
        // It shrinks into the seam on its trailing end.
        #expect(view.frame.width == 0)
        #expect(view.frame.minX == leaverSlot.maxX)
        #expect(Self.contentOrigin(view, on: overlay) == leaverSlot.origin)
    }

    @Test("A side shelf's joiner stands at its slot too")
    func verticalJoinerStandsInPlace() {
        let joinerSlot = CGRect(x: 0, y: 0, width: 40, height: 400)
        let other = Self.section(
            AppBarOverlay.FlippedView(),
            slot: CGRect(x: 0, y: 400, width: 40, height: 600)
        )
        let overlay = Self.shown([other], in: Self.tall, edge: .left)
        let view = AppBarOverlay.FlippedView()
        let joiner = Self.section(view, slot: joinerSlot)
        overlay.standGlideStarts(
            [joiner, other],
            in: Self.tall,
            horizontal: false
        )
        #expect(view.frame.height == 0)
        #expect(Self.contentOrigin(view, on: overlay) == joinerSlot.origin)
    }
}
