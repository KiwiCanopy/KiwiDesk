import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The shelf's reservation (#293, #1517): the strip on all four
/// edges, the one predicate that decides whether it is taken,
/// and the float clamp against it.
@Suite("Shelf geometry")
struct ShelfGeometryTests {
    private let visible = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )

    private func shelf(
        edge: AppBarEdge,
        thickness: CGFloat = 32
    ) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.edge = edge
        shelf.thickness = thickness
        return shelf
    }

    @Test(
        "Strip hugs its edge and remaining frame loses it",
        arguments: [AppBarEdge.top, .bottom, .left, .right]
    )
    func reservation(edge: AppBarEdge) {
        let shelf = shelf(edge: edge)
        let strip = ShelfGeometry.strip(in: visible, shelf: shelf)
        let remaining = ShelfGeometry.remainingFrame(
            in: visible,
            shelf: shelf
        )
        // Strip and remaining frame partition the visible frame:
        // disjoint, and their union spans it.
        #expect(visible.contains(strip))
        #expect(visible.contains(remaining))
        #expect(!strip.intersects(remaining))
        #expect(
            strip.width * strip.height
                + remaining.width * remaining.height
                == visible.width * visible.height
        )
        switch edge {
        case .top:
            #expect(strip.minY == visible.minY)
            #expect(remaining.minY == visible.minY + 32)
        case .bottom:
            #expect(strip.maxY == visible.maxY)
            #expect(remaining.maxY == visible.maxY - 32)
        case .left:
            #expect(strip.minX == visible.minX)
            #expect(remaining.minX == visible.minX + 32)
        case .right:
            #expect(strip.maxX == visible.maxX)
            #expect(remaining.maxX == visible.maxX - 32)
        }
    }

    /// Whether the shelf reserves is one predicate over the three
    /// Show switches — never the layout on screen, so a layout
    /// switch reflows nothing.
    @Test("The shelf reserves exactly while any bar can show")
    func reservesWhileAnyBarShows() {
        var settings = TilingSettings()
        settings.kiwishelf = shelf(edge: .left)
        settings.spaceBarStyle.enabled = false
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = false
        #expect(!settings.shelfShows)
        #expect(settings.layoutBounds(from: visible) == visible)
        let reserved = ShelfGeometry.remainingFrame(
            in: visible,
            shelf: settings.kiwishelf
        )
        for flip in [
            { (s: inout TilingSettings) in
                s.spaceBarStyle.enabled = true
            },
            { $0.monocle.appBar.enabled = true },
            { $0.scrolling.appBar.enabled = true },
        ] {
            var one = settings
            flip(&one)
            #expect(one.shelfShows)
            #expect(one.layoutBounds(from: visible) == reserved)
        }
    }

    @Test("Oversized thickness never yields a negative frame")
    func oversized() {
        let remaining = ShelfGeometry.remainingFrame(
            in: visible,
            shelf: shelf(edge: .top, thickness: 5000)
        )
        #expect(remaining.height == 0)
        #expect(remaining.width == visible.width)
    }

    /// The #242 clamp applies to the shelf's strip: a float
    /// under a top strip is pushed below it.
    @Test("Float clamp clears a top shelf strip")
    func floatClamp() {
        let strip = ShelfGeometry.strip(
            in: visible,
            shelf: shelf(edge: .top)
        )
        let float = CGRect(
            x: 100,
            y: visible.minY + 4,
            width: 400,
            height: 300
        )
        let clamped = AppBarGeometry.clampClear(
            float,
            of: strip,
            edge: .top
        )
        #expect(clamped.minY == strip.maxY)
        #expect(clamped.size == float.size)
        // Already-clear frames pass through untouched.
        let clear = CGRect(
            x: 100,
            y: strip.maxY + 10,
            width: 400,
            height: 300
        )
        #expect(
            AppBarGeometry.clampClear(
                clear,
                of: strip,
                edge: .top
            ) == clear
        )
    }

    @Test("Float clamp nudges off every edge")
    func floatClampAllEdges() {
        // AX coordinates, y grows downward; a 1000x800 screen.
        let float = CGRect(
            x: 100,
            y: 100,
            width: 400,
            height: 300
        )
        // Bottom bar at y 768...800: the float's bottom (400)
        // is clear; one overlapping is pushed up.
        let bottom = CGRect(x: 0, y: 768, width: 1000, height: 32)
        #expect(
            AppBarGeometry.clampClear(
                float,
                of: bottom,
                edge: .bottom
            ) == float
        )
        let low = CGRect(x: 100, y: 600, width: 400, height: 300)
        #expect(
            AppBarGeometry.clampClear(
                low,
                of: bottom,
                edge: .bottom
            ).maxY == bottom.minY
        )
        // Left bar at x 0...32.
        let left = CGRect(x: 0, y: 0, width: 32, height: 800)
        #expect(
            AppBarGeometry.clampClear(
                CGRect(x: 4, y: 100, width: 400, height: 300),
                of: left,
                edge: .left
            ).minX == left.maxX
        )
        // Right bar at x 968...1000.
        let right = CGRect(x: 968, y: 0, width: 32, height: 800)
        #expect(
            AppBarGeometry.clampClear(
                CGRect(x: 700, y: 100, width: 400, height: 300),
                of: right,
                edge: .right
            ).maxX == right.minX
        )
        // Sizes never change.
        #expect(
            AppBarGeometry.clampClear(
                low,
                of: bottom,
                edge: .bottom
            ).size == low.size
        )
    }
}
