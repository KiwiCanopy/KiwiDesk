import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A hiding bar's hover band covers its own mark, never the edge
/// (#761, owner 2026-10-19): one fixed length centred on the mark,
/// a push counted only inside it, and a shown bar held over its own
/// section and band alone. The marks of an edge sit as one row, so
/// two bands meet edge to edge and a point opens one bar.
@Suite("Shelf reveal bands (#761)")
@MainActor
struct ShelfRevealBandTests {
    private static let key = ShelfRevealer.Key(
        shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
        bar: .space
    )
    /// A top shelf 40 pt deep, flush with a 1000 x 800 screen's
    /// top, Cocoa coordinates.
    private static let strip = CGRect(x: 0, y: 760, width: 1000, height: 40)
    private static let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

    final class Box {
        var point = CGPoint(x: 500, y: 300)
        var delays: [TimeInterval] = []
        var timers: [() -> Void] = []
    }

    private func make(
        _ target: ShelfRevealer.Target
    ) -> (ShelfRevealer, Box) {
        let revealer = ShelfRevealer()
        let box = Box()
        revealer.makeMonitor = { _ in nil }
        revealer.location = { box.point }
        revealer.schedule = { delay, body in
            box.delays.append(delay)
            box.timers.append(body)
            return ShelfRevealTimer()
        }
        revealer.sync([Self.key: target])
        return (revealer, box)
    }

    private func move(
        _ revealer: ShelfRevealer,
        _ box: Box,
        _ x: CGFloat,
        _ y: CGFloat
    ) {
        box.point = CGPoint(x: x, y: y)
        revealer.moved(to: box.point)
    }

    @Test("the pocket's handle takes one band more at the leaning end")
    func pocketJoinsTheRow() {
        let length = ShelfMarkPlacement.bandLength
        var shelf = KiwiShelf()
        shelf.alignment = .center
        let end = ShelfMarkPlacement.row(
            for: [.space],
            pocketLeansEnd: true,
            length: 1000,
            shelf: shelf
        )
        // Two bands centred as one row, the pocket after the bar's.
        #expect(end.bars[.space] == (500 - length)...500)
        #expect(end.pocket == 500...(500 + length))
        let start = ShelfMarkPlacement.row(
            for: [.space],
            pocketLeansEnd: false,
            length: 1000,
            shelf: shelf
        )
        #expect(start.pocket == (500 - length)...500)
        #expect(start.bars[.space] == 500...(500 + length))
        let none = ShelfMarkPlacement.row(
            for: [.space],
            pocketLeansEnd: nil,
            length: 1000,
            shelf: shelf
        )
        #expect(none.pocket == nil)
    }

    @Test("marks sit as one row where a lone bar would, in order")
    func bandsFormOneRow() {
        let length = ShelfMarkPlacement.bandLength
        var shelf = KiwiShelf()
        shelf.alignment = .center
        shelf.order = .spacesFirst
        let lone = ShelfMarkPlacement.row(
            for: [.space],
            pocketLeansEnd: nil,
            length: 1000,
            shelf: shelf
        )
        #expect(lone.bars[.space] == (500 - length / 2)...(500 + length / 2))
        let pair = ShelfMarkPlacement.row(
            for: [.space, .app],
            pocketLeansEnd: nil,
            length: 1000,
            shelf: shelf
        )
        // Edge to edge, meeting at the middle of the edge.
        #expect(pair.bars[.space]?.upperBound == 500)
        #expect(pair.bars[.app]?.lowerBound == 500)
        shelf.order = .appsFirst
        let swapped = ShelfMarkPlacement.row(
            for: [.space, .app],
            pocketLeansEnd: nil,
            length: 1000,
            shelf: shelf
        )
        #expect(swapped.bars[.app]?.upperBound == 500)
        shelf.alignment = .start
        let start = ShelfMarkPlacement.row(
            for: [.space, .app],
            pocketLeansEnd: nil,
            length: 1000,
            shelf: shelf
        )
        #expect(start.bars[.app]?.lowerBound == 0)
        shelf.alignment = .end
        let end = ShelfMarkPlacement.row(
            for: [.space, .app],
            pocketLeansEnd: nil,
            length: 1000,
            shelf: shelf
        )
        #expect(end.bars[.space]?.upperBound == 1000)
    }

    @Test("the band is the mark's, never the whole edge")
    func bandIsTheMarks() {
        let band = ShelfReveal.band(of: Self.strip, edge: .top)
        #expect(band.width == ShelfMarkPlacement.bandLength)
        #expect(band.midX == Self.strip.midX)
        let (revealer, box) = make(
            .hovering(edge: .top, strip: Self.strip, screen: Self.screen)
        )
        // On the edge, far from the mark: nothing arms.
        move(revealer, box, 150, 795)
        #expect(box.delays.isEmpty)
        #expect(revealer.arming.isEmpty)
        // Over the mark: the reveal delay runs.
        move(revealer, box, 500, 795)
        #expect(box.delays == [ShelfReveal.revealDelay])
    }

    @Test("a push counts only inside the band")
    func pushIsTheBands() {
        let (revealer, box) = make(
            .hovering(edge: .top, strip: Self.strip, screen: Self.screen)
        )
        // Pressed against the screen's top in a corner: no reveal.
        move(revealer, box, 5, 800)
        #expect(revealer.reveal(of: Self.key) == .hidden)
        // Pressed against it over the mark: at once.
        move(revealer, box, 500, 800)
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("no push where a menu bar stands between")
    func noPushUnderMenuBar() {
        let strip = CGRect(x: 0, y: 735, width: 1000, height: 40)
        #expect(
            !ShelfReveal.pushes(
                CGPoint(x: 500, y: 775),
                band: ShelfReveal.band(
                    of: strip,
                    edge: .top,
                    outward: ShelfReveal.pushReach
                ),
                strip: strip,
                edge: .top,
                screen: Self.screen
            )
        )
    }

    @Test("a shown bar is held over its section, never the edge")
    func holdIsTheSection() {
        // The bar draws 400 pt, centred: wider than its band.
        let section = CGRect(x: 300, y: 760, width: 400, height: 40)
        let (revealer, box) = make(
            .hovering(
                edge: .top,
                strip: Self.strip,
                screen: Self.screen,
                section: section
            )
        )
        move(revealer, box, 500, 800)
        #expect(revealer.reveal(of: Self.key) == .hover)
        // Along the open bar, past its band: still held.
        move(revealer, box, 320, 780)
        #expect(box.delays.isEmpty)
        // Along the edge past the bar: the retract runs.
        move(revealer, box, 900, 780)
        #expect(box.delays == [ShelfReveal.retractDelay])
    }

    /// Two marks on one edge, the Space Bar's band left of the
    /// middle and the App Bar's right of it.
    private func pair() -> (ShelfRevealer, Box, ShelfRevealer.Key) {
        let app = ShelfRevealer.Key(shelf: Self.key.shelf, bar: .app)
        let length = ShelfMarkPlacement.bandLength
        let target = { (minX: CGFloat) in
            ShelfRevealer.Target.hovering(
                edge: .top,
                strip: Self.strip,
                screen: Self.screen,
                band: ShelfReveal.band(
                    of: Self.strip,
                    edge: .top,
                    along: CGRect(x: minX, y: 760, width: length, height: 40),
                    outward: ShelfReveal.pushReach
                )
            )
        }
        let (revealer, box) = make(target(500 - length))
        revealer.sync([Self.key: target(500 - length), app: target(500)])
        return (revealer, box, app)
    }

    @Test("a sibling shown stands a hidden bar's hover down")
    func siblingShownYields() {
        let (revealer, box, app) = pair()
        move(revealer, box, 480, 795)
        #expect(revealer.arming.contains(Self.key))
        #expect(revealer.toggle(app, duration: 0))
        #expect(revealer.yields(Self.key))
        move(revealer, box, 481, 795)
        #expect(!revealer.arming.contains(Self.key))
        // The delay it had armed reveals nothing.
        box.timers.forEach { $0() }
        #expect(revealer.reveal(of: Self.key) == .hidden)
        #expect(!revealer.arming.contains(Self.key))
        #expect(!revealer.yields(app))
    }

    @Test("a push at the seam of two bands opens one bar")
    func seamPushOpensOne() {
        let (revealer, box, app) = pair()
        move(revealer, box, 500, 800)
        let shown = [Self.key, app].filter {
            revealer.reveal(of: $0).isShown
        }
        #expect(shown.count == 1)
    }
}
