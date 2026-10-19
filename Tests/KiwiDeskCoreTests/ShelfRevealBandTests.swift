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

    @Test("marks sit as one row where a lone bar would")
    func bandsFormOneRow() {
        let length = ShelfMarkPlacement.bandLength
        let lone = ShelfMarkPlacement.bands(
            count: 1,
            length: 1000,
            alignment: .center
        )
        #expect(lone == [(500 - length / 2)...(500 + length / 2)])
        let pair = ShelfMarkPlacement.bands(
            count: 2,
            length: 1000,
            alignment: .center
        )
        #expect(pair.count == 2)
        // Edge to edge, meeting at the middle of the edge.
        #expect(pair[0].upperBound == 500)
        #expect(pair[1].lowerBound == 500)
        #expect(pair.allSatisfy { $0.upperBound - $0.lowerBound == length })
        let start = ShelfMarkPlacement.bands(
            count: 2,
            length: 1000,
            alignment: .start
        )
        #expect(start[0].lowerBound == 0)
        let end = ShelfMarkPlacement.bands(
            count: 2,
            length: 1000,
            alignment: .end
        )
        #expect(end[1].upperBound == 1000)
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

    @Test("a bar losing its band while hidden drops its pending hover")
    func yieldDropsTheHover() {
        let hovering = ShelfRevealer.Target.hovering(
            edge: .top,
            strip: Self.strip,
            screen: Self.screen
        )
        let (revealer, box) = make(hovering)
        move(revealer, box, 500, 795)
        #expect(revealer.arming.contains(Self.key))
        revealer.sync([
            Self.key: .init(
                edge: .top,
                strip: Self.strip,
                screen: Self.screen,
                band: nil
            )
        ])
        #expect(!revealer.arming.contains(Self.key))
        // The delay it had armed reveals nothing.
        box.timers.forEach { $0() }
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }
}
