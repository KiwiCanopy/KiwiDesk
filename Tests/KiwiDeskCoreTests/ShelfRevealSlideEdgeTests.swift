import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// Which WAY a hiding shelf slides, on every edge, as drawn (#2497):
/// the slide `playReveal` adds, carried through the layers' own
/// flipping to the screen, moves the shelf toward its screen side
/// by its depth and the outer margin, past the edge of the panel's
/// slide room, and a slide in flight continues from where it
/// stands. Main-actor spend: one ordered panel per edge.
@Suite("Shelf reveal slide per edge (#2497)", .serialized)
@MainActor
struct ShelfRevealSlideEdgeTests {
    private static let margin: CGFloat = 6
    private static let depth: CGFloat = 40

    /// A strip on `edge`, clear of the menu bar, in AX coordinates.
    private static func strip(_ edge: AppBarEdge) -> CGRect {
        edge.isHorizontal
            ? CGRect(x: 100, y: 300, width: 800, height: depth)
            : CGRect(x: 100, y: 200, width: depth, height: 600)
    }

    private func overlay(on edge: AppBarEdge) -> ShelfOverlay {
        let overlay = ShelfOverlay()
        overlay.afterReveal = { _, _ in }
        let strip = Self.strip(edge)
        let plate = CGRect(origin: .zero, size: strip.size)
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.outerMargin = Self.margin
        overlay.show(
            strip: strip,
            edge: edge,
            shelf: shelf,
            sheen: 0,
            sections: [
                .init(
                    view: NSView(),
                    slot: strip,
                    plate: plate,
                    content: plate
                )
            ]
        )
        return overlay
    }

    /// `point` in `root`'s layer, on screen (Cocoa, y up).
    private func screen(_ point: CGPoint, root: NSView) throws -> CGPoint {
        let window = try #require(root.window)
        let inView = root.convertFromLayer(point)
        return window.convertPoint(toScreen: root.convert(inView, to: nil))
    }

    @Test(
        "A retract slides toward the screen side, past its room",
        arguments: [AppBarEdge.top, .bottom, .left, .right]
    )
    func slidesTowardTheScreenSide(edge: AppBarEdge) throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = overlay(on: edge)
        defer { overlay.hide() }
        #expect(overlay.retractOut())
        let root = try #require(overlay.panel?.contentView)
        let layer = try #require(overlay.content.layer)
        let slide = try #require(
            layer.animation(forKey: BarMotion.revealKey) as? CABasicAnimation
        )
        let shift = try #require(slide.toValue as? NSValue).pointValue
        let rest = try screen(layer.position, root: root)
        let away = try screen(
            CGPoint(
                x: layer.position.x + shift.x,
                y: layer.position.y + shift.y
            ),
            root: root
        )
        let travel = Self.depth + Self.margin
        let expected: CGVector
        switch edge {
        case .top: expected = CGVector(dx: 0, dy: travel)
        case .bottom: expected = CGVector(dx: 0, dy: -travel)
        case .left: expected = CGVector(dx: -travel, dy: 0)
        case .right: expected = CGVector(dx: travel, dy: 0)
        }
        #expect(abs(away.x - rest.x - expected.dx) < 0.5, "\(edge)")
        #expect(abs(away.y - rest.y - expected.dy) < 0.5, "\(edge)")
        // At its start the shelf lies wholly outside the room, so
        // the panel's edge hides it.
        let panel = try #require(overlay.panel)
        let content = overlay.content
        let drawn = panel.convertToScreen(
            content.convert(content.bounds, to: nil)
        )
        let start = drawn.offsetBy(
            dx: away.x - rest.x,
            dy: away.y - rest.y
        )
        #expect(!start.intersects(panel.frame), "\(edge)")
        #expect(drawn.intersects(panel.frame), "\(edge)")
    }

    @Test("A slide in flight continues from where it stands")
    func takesTheShiftInFlight() throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let view = NSView()
        view.wantsLayer = true
        let standing = CGPoint(x: 0, y: 12)
        BarMotion.playReveal(
            view,
            offset: CGVector(dx: 0, dy: -46),
            entering: true,
            from: standing
        )
        let slide = try #require(
            view.layer?.animation(forKey: BarMotion.revealKey)
                as? CABasicAnimation
        )
        let from = try #require(slide.fromValue as? NSValue).pointValue
        #expect(from == standing)
    }
}
