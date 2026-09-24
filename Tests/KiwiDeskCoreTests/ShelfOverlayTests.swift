import AppKit
import Testing

@testable import KiwiDeskCore

/// One display's shelf draws ONE plate under both sections and a
/// divider between them (#1517).
@Suite("Shelf overlay")
@MainActor
struct ShelfOverlayTests {
    private static let strip = CGRect(x: 100, y: 0, width: 1000, height: 40)

    private func section(
        slot: CGRect,
        plate: CGRect
    ) -> ShelfOverlay.Section {
        .init(view: NSView(), slot: slot, plate: plate)
    }

    @Test("Both sections' asks join into one plate")
    func plateJoins() {
        let space = section(
            slot: CGRect(x: 350, y: 0, width: 300, height: 40),
            plate: CGRect(x: 0, y: 0, width: 300, height: 40)
        )
        let app = section(
            slot: CGRect(x: 656, y: 0, width: 200, height: 40),
            plate: CGRect(x: 0, y: 0, width: 200, height: 40)
        )
        let plate = ShelfOverlay.plateFrame(
            sections: [space, app],
            strip: Self.strip,
            shelf: KiwiShelf()
        )
        // One rect from the Space section's start to the App
        // section's end, gutter included, in strip coordinates.
        #expect(plate == CGRect(x: 250, y: 0, width: 506, height: 40))
    }

    @Test("Full spans the strip; Boxed draws no plate")
    func plateModes() {
        let lone = section(
            slot: Self.strip,
            plate: CGRect(x: 400, y: 0, width: 200, height: 40)
        )
        var full = KiwiShelf()
        full.backgroundFit = .full
        full.liquidGlass = false
        #expect(
            ShelfOverlay.plateFrame(
                sections: [lone],
                strip: Self.strip,
                shelf: full
            ) == CGRect(x: 0, y: 0, width: 1000, height: 40)
        )
        var boxed = KiwiShelf()
        boxed.backgroundStyle = .boxed
        boxed.liquidGlass = false
        #expect(
            ShelfOverlay.plateFrame(
                sections: [lone],
                strip: Self.strip,
                shelf: boxed
            ) == nil
        )
    }

    @Test("The divider sits centred in the gutter, only for two")
    func dividerInTheGutter() {
        let slots = [
            CGRect(x: 656, y: 0, width: 200, height: 40),
            CGRect(x: 350, y: 0, width: 300, height: 40),
        ]
        let frame = ShelfOverlay.dividerFrame(
            slots: slots,
            strip: Self.strip,
            horizontal: true
        )
        // Gutter 650…656, centre 653, strip-local 553; a section
        // break thick, 70% of the 40 pt depth.
        #expect(frame == CGRect(x: 552, y: 6, width: 2, height: 28))
        #expect(
            ShelfOverlay.dividerFrame(
                slots: [slots[0]],
                strip: Self.strip,
                horizontal: true
            ) == nil
        )
    }
}
