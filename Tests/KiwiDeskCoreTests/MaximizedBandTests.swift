import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The band a maximized window's bar comes in through (#3346): no
/// handle draws, so the band runs along the whole edge, split where
/// two bars' row bands meet, and reaches only outward past the
/// shelf's screen side, never in over the window's own chrome.
@Suite("Maximized hover band (#3346)")
struct MaximizedBandTests {
    private let length: CGFloat = 1600

    @Test("A lone bar's band spans the whole edge")
    func loneBarSpansTheEdge() {
        let shelf = KiwiShelf()
        // Control: the handle's own band is its fixed length.
        let row = ShelfMarkPlacement.row(
            for: [.space],
            pocket: nil,
            length: length,
            shelf: shelf
        )
        #expect(
            row.bars[.space].map { $0.upperBound - $0.lowerBound }
                == ShelfMarkPlacement.bandLength
        )
        let bands = ShelfMarkPlacement.maximizedBands(
            for: [.space],
            length: length,
            shelf: shelf
        )
        #expect(bands == [.space: 0...length])
    }

    @Test("Two bars split the edge where their row bands meet")
    func twoBarsSplitAtTheSeam() {
        for order in KiwiShelf.Order.allCases {
            var shelf = KiwiShelf()
            shelf.order = order
            let row = ShelfMarkPlacement.row(
                for: [.space, .app],
                pocket: nil,
                length: length,
                shelf: shelf
            )
            let bands = ShelfMarkPlacement.maximizedBands(
                for: [.space, .app],
                length: length,
                shelf: shelf
            )
            let first: ShelfBar = order == .spacesFirst ? .space : .app
            let last: ShelfBar = first == .space ? .app : .space
            let seam = row.bars[first]?.upperBound ?? -1
            #expect(seam > 0 && seam < length, "\(order)")
            #expect(bands[first] == 0...seam, "\(order)")
            #expect(bands[last] == seam...length, "\(order)")
        }
    }

    @Test("No bar, no band")
    func noBarNoBand() {
        #expect(
            ShelfMarkPlacement.maximizedBands(
                for: [],
                length: length,
                shelf: KiwiShelf()
            ).isEmpty
        )
    }

    @Test("The band reaches out past the screen side, never in")
    @MainActor
    func bandStaysOffTheWindow() throws {
        var shelf = KiwiShelf()
        shelf.outerMargin = 3
        let strip = CGRect(x: 0, y: 25, width: length, height: 40)
        let plan = KiwiCore.ShelfPlan(
            edge: .top,
            strip: strip,
            horizontal: true,
            arrangement: ShelfArrangement(),
            shelfEdge: ShelfEdge(
                .top,
                reserves: true,
                bars: [.space: .hidden]
            )
        )
        let bands = KiwiCore.HidingShelves.maximizedBands(
            [.space],
            of: plan,
            shelf: shelf
        )
        let band = try #require(bands[.space])
        let cocoa = GeometryUtils.flip(
            strip,
            primaryHeight: GeometryUtils.primaryHeight
        )
        // Cocoa: the strip's screen side is its top, `maxY`.
        #expect(band.minY == cocoa.maxY)
        #expect(
            band.height == shelf.outerMargin + ShelfReveal.overshoot
        )
        #expect(band.minX == cocoa.minX && band.width == cocoa.width)
    }
}
