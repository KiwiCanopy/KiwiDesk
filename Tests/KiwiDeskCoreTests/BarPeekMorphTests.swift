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

    /// Every list but a collapsed chip's opens on a click alone
    /// (#2571); only the overflow mark's grows out of its pill, and a
    /// one-window label stays the hover's.
    @Test("Which sources a click opens, and how each grows")
    func onlyTheRunMorphs() {
        let ids = [WindowID(1), WindowID(2)]
        let one = [WindowID(1)]
        let table: [(BarPeekSource, BarPeekSource.Growth?)] = [
            (.run(ids), .fromPill),
            (.run(one), .fromPill),
            (.overflow(ids), .outOfItem),
            (.overflow(one), .outOfItem),
            (.glyph(ids), .outOfItem),
            (.appItem(ids), .outOfItem),
            (.glyph(one), nil),
            (.appItem(one), nil),
            (.space(ids), nil),
        ]
        for (source, growth) in table {
            #expect(source.clickGrowth == growth, "\(source)")
            #expect(source.opensOnClick == (growth != nil), "\(source)")
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

    /// The header sits on the pill on a side end too, so the count
    /// holds its place and a double-click's second press lands on
    /// the header, never a row (#2063).
    @Test("A side end grows inward, its header on the pill")
    func sideEndHangsFromThePill() {
        let pill = CGRect(x: 882, y: 391, width: 18, height: 18)
        let list = BarPeekMorph.listFrame(
            size: size,
            pill: pill,
            edge: .right,
            room: room
        )
        #expect(list.maxX == pill.maxX)
        #expect(list.maxY == pill.maxY)
        let count = BarPeekMorph.count(
            width: pill.width,
            pill: pill,
            list: list,
            edge: .right
        )
        #expect(count.offsetBy(dx: list.minX, dy: list.minY) == pill)
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
        // Pills set in from the room's edges, so a formula reading
        // the room's height alone answers differently.
        let high = CGRect(x: 480, y: 500, width: 40, height: 18)
        #expect(
            BarPeekMorph.maxHeight(pill: high, edge: .top, room: room)
                == high.maxY - room.minY
        )
        let pill = CGRect(x: 480, y: 300, width: 40, height: 18)
        #expect(
            BarPeekMorph.maxHeight(pill: pill, edge: .bottom, room: room)
                == room.maxY - pill.minY
        )
        #expect(
            BarPeekMorph.maxHeight(pill: high, edge: .left, room: room)
                == high.maxY - room.minY
        )
    }

    /// A list taller than the room below a side pill is cut to it,
    /// so the clamp never lifts the header off the pill.
    @Test("A tall side-end list keeps its header on the pill")
    func tallSideListKeepsTheHeader() {
        let pill = CGRect(x: 882, y: 200, width: 18, height: 18)
        let tall = CGSize(width: 200, height: 500)
        let cut = CGSize(
            width: tall.width,
            height: min(
                tall.height,
                BarPeekMorph.maxHeight(pill: pill, edge: .right, room: room)
            )
        )
        let list = BarPeekMorph.listFrame(
            size: cut,
            pill: pill,
            edge: .right,
            room: room
        )
        #expect(list.maxY == pill.maxY)
        #expect(list.minY >= room.minY)
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
