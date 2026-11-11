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

    private func shelf(thickness: CGFloat = 32) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.thickness = thickness
        return shelf
    }

    @Test(
        "Strip hugs its edge and remaining frame loses it",
        arguments: [AppBarEdge.top, .bottom, .left, .right]
    )
    func reservation(edge: AppBarEdge) {
        let shelf = shelf()
        let strip = ShelfGeometry.strip(
            in: visible,
            edge: edge,
            shelf: shelf
        )
        let remaining = ShelfGeometry.remainingFrame(
            in: visible,
            edges: [edge],
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

    /// The strip is reserved exactly where a bar draws: the Space
    /// Bar draws in every layout, an App Bar only in its own. A
    /// layout that draws no bar keeps the whole screen.
    @Test("The shelf reserves exactly where a bar draws")
    func reservesWhereABarDraws() {
        var settings = TilingSettings()
        settings.kiwishelf = shelf()
        settings.barEdge = .left
        settings.spaceBarStyle.visibility = .hidden
        settings.monocle.appBar.visibility = .hidden
        settings.scrolling.appBar.visibility = .hidden
        let reserved = ShelfGeometry.remainingFrame(
            in: visible,
            edges: [.left],
            shelf: settings.kiwishelf
        )
        func bounds(_ s: TilingSettings, _ mode: LayoutMode) -> CGRect {
            s.layoutBounds(
                from: visible,
                mode: mode,
                on: nil,
                pocketAtRest: false
            )
        }
        for mode in LayoutMode.allCases {
            #expect(bounds(settings, mode) == visible, "\(mode)")
        }
        var spaceBar = settings
        spaceBar.spaceBarStyle.visibility = .always
        for mode in LayoutMode.allCases {
            #expect(bounds(spaceBar, mode) == reserved, "\(mode)")
        }
        var monocle = settings
        monocle.monocle.appBar.visibility = .always
        #expect(bounds(monocle, .monocle) == reserved)
        #expect(bounds(monocle, .scrolling) == visible)
        #expect(bounds(monocle, .bsp) == visible)
        var scrolling = settings
        scrolling.scrolling.appBar.visibility = .always
        #expect(bounds(scrolling, .scrolling) == reserved)
        #expect(bounds(scrolling, .monocle) == visible)
    }

    @Test("Oversized thickness never yields a negative frame")
    func oversized() {
        let remaining = ShelfGeometry.remainingFrame(
            in: visible,
            edges: [.top],
            shelf: shelf(thickness: 5000)
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
            edge: .top,
            shelf: shelf()
        )
        let float = CGRect(
            x: 100,
            y: visible.minY + 4,
            width: 400,
            height: 300
        )
        let clamped = AppBarGeometry.pushedBelow(
            float,
            strip: strip
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
            AppBarGeometry.pushedBelow(
                clear,
                strip: strip
            ) == clear
        )
    }
}
