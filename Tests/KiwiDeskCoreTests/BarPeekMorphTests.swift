import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Where the overflow mark's list stands as its pill grows into it
/// (#2563 ▸ Ruling), and when its header closes it. Pure, AppKit
/// screen coordinates (y up).
@Suite("Overflow list morph geometry (#2563)")
struct BarPeekMorphTests {
    private let room = CGRect(x: 100, y: 100, width: 800, height: 600)
    private let size = CGSize(width: 200, height: 150)

    /// A top end's pill, centred on a window in the middle.
    private var topPill: CGRect {
        CGRect(x: 480, y: 682, width: 40, height: 18)
    }

    @Test("Only the overflow mark's source grows out of its anchor")
    func onlyTheRunMorphs() {
        let ids = [WindowID(1), WindowID(2)]
        #expect(BarPeekSource.run(ids).morphsFromAnchor)
        for source: BarPeekSource in [
            .glyph(ids), .overflow(ids), .appItem(ids), .space(ids),
        ] {
            #expect(!source.morphsFromAnchor, "\(source)")
        }
    }

    @Test("A top end's list hangs from the pill's outer edge, centred")
    func topEndIsFlushAndCentred() {
        let list = BarPeekMorph.listFrame(
            size: size,
            pill: topPill,
            edge: .top,
            room: room
        )
        #expect(list.maxY == topPill.maxY)
        #expect(list.midX == topPill.midX)
        #expect(list.contains(topPill))
    }

    @Test("A bottom end's list stands on the pill's outer edge")
    func bottomEndIsFlush() {
        let pill = CGRect(x: 480, y: 100, width: 40, height: 18)
        let list = BarPeekMorph.listFrame(
            size: size,
            pill: pill,
            edge: .bottom,
            room: room
        )
        #expect(list.minY == pill.minY)
        #expect(list.midX == pill.midX)
        #expect(!BarPeekMorph.headerAtTop(.bottom))
    }

    /// Clamping shifts the container and never the count: it keeps
    /// the pill's x inside the moved list.
    @Test("A clamped list keeps the count at the mark's x")
    func clampKeepsTheCount() {
        let pill = CGRect(x: 110, y: 682, width: 40, height: 18)
        let list = BarPeekMorph.listFrame(
            size: size,
            pill: pill,
            edge: .top,
            room: room
        )
        #expect(list.minX == room.minX)
        let count = BarPeekMorph.count(
            width: pill.width,
            pill: pill,
            list: list,
            edge: .top
        )
        #expect(count.minX + list.minX == pill.minX)
        #expect(count.maxY == list.height)
    }

    @Test("A side end grows inward, centred vertically on the mark")
    func sideEndIsCentredVertically() {
        let pill = CGRect(x: 882, y: 391, width: 18, height: 18)
        let list = BarPeekMorph.listFrame(
            size: size,
            pill: pill,
            edge: .right,
            room: room
        )
        #expect(list.maxX == pill.maxX)
        #expect(list.midY == pill.midY)
        let left = CGRect(x: 100, y: 391, width: 18, height: 18)
        #expect(
            BarPeekMorph.listFrame(
                size: size,
                pill: left,
                edge: .left,
                room: room
            ).minX == left.minX
        )
    }

    @Test("The list's height stops at the room's far edge")
    func heightStopsAtTheRoom() {
        #expect(
            BarPeekMorph.maxHeight(pill: topPill, edge: .top, room: room)
                == topPill.maxY - room.minY
        )
        let pill = CGRect(x: 480, y: 100, width: 40, height: 18)
        #expect(
            BarPeekMorph.maxHeight(pill: pill, edge: .bottom, room: room)
                == room.maxY - pill.minY
        )
        #expect(
            BarPeekMorph.maxHeight(pill: pill, edge: .left, room: room)
                == room.height
        )
    }

    /// The double-click that opens stays open (#2063): its second
    /// press lands on the header the list put where the pill was.
    @Test("The header closes on a single click past the double-click")
    func headerClosesPastTheDoubleClick() {
        let interval = 0.5
        #expect(
            BarPeekMorph.headerCloses(
                clickCount: 1,
                sinceOpen: 1,
                doubleClick: interval
            )
        )
        #expect(
            !BarPeekMorph.headerCloses(
                clickCount: 2,
                sinceOpen: 1,
                doubleClick: interval
            )
        )
        #expect(
            !BarPeekMorph.headerCloses(
                clickCount: 1,
                sinceOpen: 0.2,
                doubleClick: interval
            )
        )
    }
}
