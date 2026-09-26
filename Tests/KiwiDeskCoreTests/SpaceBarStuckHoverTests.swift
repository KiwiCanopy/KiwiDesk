import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar item's hover follows the resting pointer across renders
/// and shelf placements (#1665): a click re-lays the bar, a chip
/// moves out from under a resting pointer, AppKit sends no exit,
/// and the hover fill stayed until the pointer crossed the chip
/// again. Driven in `updateBars`' own order — the Space Bar
/// renders with the shelf's relayout held, then the shelf places
/// the section in its panel.
@Suite("Space Bar stuck hover (#1665)", .serialized)
@MainActor
struct SpaceBarStuckHoverTests {
    private let spaceBars = SpaceBarManager()
    private let shelves = ShelfManager()

    init() {
        LiquidGlassGate.override = { false }
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    /// One render and placement, as `updateBars` runs them; the
    /// Space Bar draws into `strip`, the shelf spans the fixture.
    private func update(active: String, strip: CGRect = barTitleStrip) {
        var style = SpaceBarLook()
        style.liquidGlass = false
        let items = ["1", "2", "3"].map {
            SpaceBarOverlay.Item(
                space: SpaceID($0),
                spaceGlyph: .text($0, tinted: true),
                apps: [],
                active: $0 == active,
                overflow: 0,
                focusInOverflow: false
            )
        }
        shelves.holdingRelayout {
            spaceBars.sync([
                SpaceBarManager.Bar(
                    display: barTitleDisplay,
                    items: items,
                    strip: strip,
                    style: style,
                    stateMarkColors: StateMarkColors(
                        sticky: "#ffffff",
                        floating: "#ffffff"
                    )
                )
            ])
        }
        shelves.sync([
            .init(
                display: barTitleDisplay,
                strip: barTitleStrip,
                shelf: KiwiShelf(),
                space: spaceBars.overlayForTesting(barTitleDisplay),
                app: nil
            )
        ])
    }

    private func chip(_ space: String) throws -> SpaceBarItemView {
        let overlay = try #require(
            spaceBars.overlayForTesting(barTitleDisplay)
        )
        let view = try #require(
            overlay.itemViews.first { $0.space == SpaceID(space) }
        )
        // Placed in the shelf's panel, or the hit test has no tree.
        try #require(view.window != nil)
        return view
    }

    /// The chip's centre in its window's points.
    private func centre(of view: NSView) -> CGPoint {
        view.convert(
            CGPoint(x: view.bounds.midX, y: view.bounds.midY),
            to: nil
        )
    }

    private func rest(at point: CGPoint) {
        BarHoverHit.pointerOverride = { _ in point }
    }

    @Test("a placement re-reads the hover from where the pointer rests")
    func placementFollowsThePointer() throws {
        defer { rest(at: BarHoverHit.offWindow) }
        update(active: "1")
        let two = try chip("2")
        rest(at: centre(of: two))
        update(active: "1")
        // The positive arm, so the negative ones are not vacuous.
        #expect(two.isHovered)
    }

    @Test("an inactive chip the pointer left without an exit unhovers")
    func leftWithoutAnExit() throws {
        defer { rest(at: BarHoverHit.offWindow) }
        update(active: "1")
        let two = try chip("2")
        let window = try #require(two.window)
        let moved = try #require(
            NSEvent.mouseEvent(
                with: .mouseMoved,
                location: centre(of: two),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            )
        )
        two.mouseMoved(with: moved)
        #expect(two.isHovered)
        // A click on 3 re-lays the bar and the pointer ends off
        // every chip with no exit; 2 stays inactive throughout.
        rest(at: BarHoverHit.offWindow)
        update(active: "3")
        #expect(!two.isHovered)
    }

    @Test("a shelf-only move re-reads the hover")
    func shelfMoveFollowsThePointer() throws {
        defer { rest(at: BarHoverHit.offWindow) }
        update(active: "1")
        let two = try chip("2")
        rest(at: centre(of: two))
        update(active: "1")
        #expect(two.isHovered)
        // The same render placed further along the shelf: the
        // chip moves on screen, the pointer does not.
        update(active: "1", strip: barTitleStrip.offsetBy(dx: 600, dy: 0))
        #expect(!two.isHovered)
    }

    @Test("an active chip never hovers")
    func activeChipNeverHovers() throws {
        defer { rest(at: BarHoverHit.offWindow) }
        update(active: "1")
        let two = try chip("2")
        rest(at: centre(of: two))
        update(active: "2")
        #expect(!two.isHovered)
    }

    @Test("clearing a drag re-reads the hover")
    func dragClearFollowsThePointer() throws {
        defer { rest(at: BarHoverHit.offWindow) }
        update(active: "1")
        let two = try chip("2")
        rest(at: centre(of: two))
        update(active: "1")
        #expect(two.isHovered)
        rest(at: BarHoverHit.offWindow)
        spaceBars.clearDragFeedback()
        #expect(!two.isHovered)
    }
}
