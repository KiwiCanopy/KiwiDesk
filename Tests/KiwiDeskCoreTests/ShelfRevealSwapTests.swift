import AppKit
import Testing

@testable import KiwiDeskCore

/// Swapping which bar a revealed shelf shows while the first still
/// retracts (#2500, accepted limitation): the arriving bar grows out
/// of the leaving section instead of sliding, since the slide moves
/// the shelf's whole content as one layer. Only the END state is
/// pinned — the arriving bar drawn, the leaving one gone, nothing
/// in flight, the room settled, and the shelf never reported gone.
@Suite("Shelf reveal swap mid-retract (#2500)", .serialized)
@MainActor
struct ShelfRevealSwapTests {
    /// Clear of the menu bar, which AppKit keeps a panel below.
    private static let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)

    private static func section(
        _ view: NSView,
        at x: CGFloat
    ) -> ShelfOverlay.Section {
        let plate = CGRect(x: x, y: 0, width: 300, height: 40)
        return .init(view: view, slot: strip, plate: plate, content: plate)
    }

    @Test("A swap inside a retract lands on the arriving bar alone")
    func swapEndsOnTheArrivingBar() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        pinShelfGlide()
        let overlay = ShelfOverlay()
        defer { overlay.hide() }
        var reveals: [() -> Void] = []
        var glides: [() -> Void] = []
        var left = 0
        overlay.afterReveal = { _, body in reveals.append(body) }
        overlay.afterGlide = { glides.append($0) }
        overlay.afterCommit = { $0() }
        overlay.onLeft = { left += 1 }
        overlay.slides = true
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        let show = { (section: ShelfOverlay.Section) in
            overlay.show(
                strip: Self.strip,
                edge: .top,
                shelf: shelf,
                sheen: 0,
                sections: [section]
            )
        }
        let app = NSView()
        let space = NSView()
        show(Self.section(app, at: 600))
        for landing in reveals { landing() }
        reveals = []
        #expect(overlay.hide(animated: true))
        // The swap, before the retract lands.
        show(Self.section(space, at: 200))
        while !reveals.isEmpty || !glides.isEmpty {
            let pending = reveals + glides
            reveals = []
            glides = []
            for landing in pending { landing() }
        }
        #expect(space.superview === overlay.stripView)
        #expect(space.alphaValue == 1)
        #expect(app.superview == nil)
        #expect(overlay.revealing == nil)
        #expect(overlay.leaving == nil)
        #expect(left == 0)
        #expect(overlay.isVisible)
        let panel = try #require(overlay.panel)
        let rest = CGRect(x: 200, y: 0, width: 300, height: 40)
        #expect(
            panel.frame
                == GeometryUtils.flip(
                    rest.offsetBy(dx: Self.strip.minX, dy: Self.strip.minY),
                    primaryHeight: GeometryUtils.primaryHeight
                )
        )
    }
}
