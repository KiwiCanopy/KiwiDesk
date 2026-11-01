import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Boxed shelf sets its two sections apart by the gap alone
/// (#2893): the divider line draws only on a plate, while the
/// grip still answers the pointer in its hover ink.
@Suite("Boxed shelf divider")
@MainActor
struct ShelfBoxedDividerTests {
    private func shown(_ shelf: KiwiShelf) -> ShelfOverlay {
        let overlay = ShelfOverlay()
        overlay.show(
            strip: CGRect(x: 0, y: 0, width: 400, height: 30),
            edge: .top,
            shelf: shelf,
            sheen: 0,
            sections: [
                .init(
                    view: NSView(),
                    slot: CGRect(x: 0, y: 0, width: 200, height: 30),
                    plate: .zero,
                    content: .zero
                ),
                .init(
                    view: NSView(),
                    slot: CGRect(x: 200, y: 0, width: 200, height: 30),
                    plate: .zero,
                    content: .zero
                ),
            ]
        )
        return overlay
    }

    @Test("Boxed draws no line at rest; a plate does")
    func lineFollowsThePlate() throws {
        LiquidGlassGate.override = { false }
        var boxed = KiwiShelf()
        boxed.backgroundStyle = .boxed
        let box = shown(boxed)
        let clear = try #require(box.divider.layer?.backgroundColor)
        #expect(clear.alpha == 0)
        box.hide()
        let plate = shown(KiwiShelf())
        let ink = try #require(plate.divider.layer?.backgroundColor)
        #expect(ink.alpha == BarDivider.sectionAlpha)
        plate.hide()
    }

    @Test("A hovered boxed grip still shows its hover ink")
    func hoverStillShows() throws {
        LiquidGlassGate.override = { false }
        var boxed = KiwiShelf()
        boxed.backgroundStyle = .boxed
        let overlay = shown(boxed)
        overlay.setDividerHovered(true)
        let ink = try #require(overlay.divider.layer?.backgroundColor)
        #expect(ink.alpha > 0)
        overlay.hide()
    }
}
