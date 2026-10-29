import AppKit
import Testing

@testable import KiwiDeskCore

/// The pocket as a shelf section (#2678): drawn in a panel the shelf
/// owns, beside its own, so a Hug gap between the bars' run and the
/// pocket still passes clicks (#2497), while every motion the shelf
/// plays reaches the pocket's content from the same call and the
/// pocket's panel stands above the shelf's.
@Suite("Shelf pocket panel (#2678)", .serialized)
@MainActor
struct ShelfPocketPanelTests {
    /// Clear of the menu bar, which AppKit keeps a panel below.
    private static let strip = CGRect(x: 100, y: 300, width: 1000, height: 40)
    /// The pocket's pinned slot at the strip's far end, AX.
    private static let slot = CGRect(x: 1060, y: 300, width: 40, height: 40)

    private static var hug: KiwiShelf {
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.backgroundStyle = .plain
        shelf.backgroundFit = .hug
        return shelf
    }

    /// A run over the strip's first 300 pt, in its own coordinates.
    private static func section() -> ShelfOverlay.Section {
        let plate = CGRect(x: 0, y: 0, width: 300, height: 40)
        return .init(
            view: NSView(),
            slot: strip,
            plate: plate,
            content: plate
        )
    }

    private static func onScreen(_ rect: CGRect) -> CGRect {
        GeometryUtils.flip(
            rect.offsetBy(dx: strip.minX, dy: strip.minY),
            primaryHeight: GeometryUtils.primaryHeight
        )
    }

    private func show(
        _ overlay: ShelfOverlay,
        pocket: NSView?
    ) {
        overlay.show(
            strip: Self.strip,
            edge: .top,
            shelf: Self.hug,
            sheen: 0,
            sections: [Self.section()],
            pocket: pocket.map {
                ShelfPocketPiece.Mount(view: $0, slot: Self.slot)
            }
        )
    }

    @Test("under Hug the gap between the run and the pocket stays clear")
    func hugGapStaysClear() throws {
        let overlay = ShelfOverlay()
        let pocket = NSView()
        show(overlay, pocket: pocket)
        let shelf = try #require(overlay.panel)
        let piece = try #require(overlay.pocket.panel)
        // The shelf's panel covers the run alone, the pocket's its
        // slot alone: the 660 pt between them belongs to neither.
        #expect(
            shelf.frame
                == Self.onScreen(
                    CGRect(x: 0, y: 0, width: 300, height: 40)
                )
        )
        #expect(
            piece.frame
                == Self.onScreen(
                    CGRect(x: 960, y: 0, width: 40, height: 40)
                )
        )
        #expect(pocket.superview === overlay.pocket.items)
        #expect(pocket.frame.origin == CGPoint(x: 960, y: 0))
        overlay.hide()
    }

    @Test("the pocket's panel is ordered above the shelf's")
    func ordersAboveTheShelf() throws {
        let overlay = ShelfOverlay()
        var pairs: [(NSWindow, NSWindow)] = []
        overlay.pocket.orderAbove = { pairs.append(($0, $1)) }
        show(overlay, pocket: NSView())
        let pair = try #require(pairs.last)
        #expect(pair.0 === overlay.pocket.panel)
        #expect(pair.1 === overlay.panel)
        overlay.hide()
    }

    @Test("a reveal plays on the pocket's content too")
    func revealReachesThePocket() throws {
        let overlay = ShelfOverlay()
        overlay.slides = true
        overlay.afterCommit = { _ in }
        show(overlay, pocket: NSView())
        #expect(overlay.motionContents.count == 2)
        let shelfKeys = overlay.content.layer?.animationKeys() ?? []
        let pocketKeys = overlay.pocket.content.layer?.animationKeys() ?? []
        #expect(shelfKeys.contains(BarMotion.revealKey))
        #expect(pocketKeys.contains(BarMotion.revealKey))
        overlay.hide()
    }

    @Test("a grow or unfold reaches the pocket's slot")
    func revealPlateTakesThePocket() throws {
        let overlay = ShelfOverlay()
        show(overlay, pocket: NSView())
        let plate = try #require(overlay.revealPlate?.frame)
        let rest = try #require(overlay.pocket.rest)
        #expect(plate.contains(rest))
        overlay.hide()
    }

    @Test("a shelf with no pocket mounts none and orders no pocket panel")
    func noPocketNoPanel() {
        let overlay = ShelfOverlay()
        show(overlay, pocket: nil)
        #expect(!overlay.pocket.isMounted)
        #expect(overlay.motionContents.count == 1)
        #expect(overlay.pocket.panel?.isVisible != true)
        overlay.hide()
    }

    @Test("the shelf leaving orders the pocket's panel out")
    func leavesWithTheShelf() {
        let overlay = ShelfOverlay()
        show(overlay, pocket: NSView())
        overlay.hide()
        #expect(overlay.pocket.panel?.isVisible != true)
    }

    @Test("a pocket moved to another shelf stays when the first lets go")
    func movedPocketStaysOnItsNewShelf() {
        let first = ShelfOverlay()
        let second = ShelfOverlay()
        let pocket = NSView()
        show(first, pocket: pocket)
        // Its screen's other shelf takes the pocket, then the first
        // shelf carries none and its leave lands.
        show(second, pocket: pocket)
        show(first, pocket: nil)
        first.pocket.orderOut()
        first.hide()
        #expect(pocket.superview === second.pocket.items)
        #expect(second.pocket.isMounted)
        second.hide()
    }
}
