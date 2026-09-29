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
        .init(view: NSView(), slot: slot, plate: plate, content: .zero)
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
            horizontal: true,
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
                horizontal: true,
                shelf: full
            ) == CGRect(x: 0, y: 0, width: 1000, height: 40)
        )
        // Boxed draws no plate, solid boxes or glass ones.
        for glass in [false, true] {
            var boxed = KiwiShelf()
            boxed.backgroundStyle = .boxed
            boxed.liquidGlass = glass
            #expect(
                ShelfOverlay.plateFrame(
                    sections: [lone],
                    strip: Self.strip,
                    horizontal: true,
                    shelf: boxed
                ) == nil,
                Comment(rawValue: "glass: \(glass)")
            )
        }
    }

    @Test("The divider sits centred in the drawn gap, only for two")
    func dividerInTheDrawnGap() {
        let slots = [
            CGRect(x: 656, y: 0, width: 200, height: 40),
            CGRect(x: 350, y: 0, width: 300, height: 40),
        ]
        let frame = ShelfOverlay.dividerFrame(
            slots: slots,
            contents: [
                CGRect(x: 2, y: 0, width: 150, height: 40),
                CGRect(x: 0, y: 0, width: 292, height: 40),
            ],
            strip: Self.strip,
            horizontal: true
        )
        // Drawn gap 642…658 (the second section's content ends 8 in
        // from its slot, the first's starts 2 in), centre 650,
        // strip-local 550; a section break thick, 70% of the 40 pt
        // depth (#1779).
        #expect(frame == CGRect(x: 549, y: 6, width: 2, height: 28))
        #expect(
            ShelfOverlay.dividerFrame(
                slots: [slots[0]],
                contents: [.zero],
                strip: Self.strip,
                horizontal: true
            ) == nil
        )
    }
}
