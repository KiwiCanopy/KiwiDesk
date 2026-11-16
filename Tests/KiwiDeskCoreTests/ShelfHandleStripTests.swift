import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An Auto bar's handle runs along its whole bar (#3349): the
/// handle on the bar's run against the screen side, its approach
/// about it — 24 pt in, over a maximized window only to its hover
/// band (#3346) — cut where two bars meet so a point
/// opens one bar, and a shown bar held over its section alone.
@Suite("Shelf handle along the bar (#3349)")
@MainActor
struct ShelfHandleStripTests {
    private static let key = ShelfRevealer.Key(
        shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
        bar: .space
    )
    /// A top shelf 40 pt deep, flush with a 1000 x 800 screen's
    /// top, Cocoa coordinates.
    private static let strip = CGRect(
        x: 0,
        y: 760,
        width: 1000,
        height: 40
    )
    private static let screen = CGRect(
        x: 0,
        y: 0,
        width: 1000,
        height: 800
    )

    final class Box {
        var point = CGPoint(x: 500, y: 300)
        var delays: [TimeInterval] = []
        var timers: [() -> Void] = []
    }

    private func make(
        _ targets: [ShelfRevealer.Key: ShelfRevealer.Target]
    ) -> (ShelfRevealer, Box) {
        let revealer = ShelfRevealer()
        revealer.macEdges = { .none }
        let box = Box()
        revealer.makeMonitor = { _ in nil }
        revealer.location = { box.point }
        revealer.schedule = { delay, body in
            box.delays.append(delay)
            box.timers.append(body)
            return ShelfRevealTimer()
        }
        revealer.sync(targets)
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

    /// A top handle along x 300–700, its area's screen side at AX
    /// y 0.
    private func spec() -> ShelfHandleSpec {
        ShelfHandleSpec(
            frame: ShelfHandleSpec.frame(
                along: CGRect(x: 300, y: 0, width: 400, height: 30),
                edge: .top,
                side: 0
            ),
            edge: .top,
            shown: false,
            reveal: .slide
        )
    }

    private func target(
        _ spec: ShelfHandleSpec,
        maximized: Bool = false,
        beyond: Bool = false,
        cut: (lead: Bool, trail: Bool) = (false, false)
    ) -> ShelfRevealer.Target {
        KiwiCore.HidingShelves.target(
            spec,
            side: 0,
            strip: Self.strip,
            screen: Self.screen,
            beyond: beyond,
            section: nil,
            maximized: maximized,
            cut: cut
        )
    }

    @Test("the pocket's handle stands where the shown pocket does")
    func pocketStandsOnTheSlot() {
        let length = ShelfMarkPlacement.bandLength
        // Kept whole on the edge at its end.
        #expect(
            ShelfMarkPlacement.pocketBand(slot: 960...1000, length: 1000)
                == (1000 - length)...1000
        )
        // Centred on a slot mid-edge.
        #expect(
            ShelfMarkPlacement.pocketBand(slot: 480...520, length: 1000)
                == (500 - length / 2)...(500 + length / 2)
        )
    }

    @Test("the handle runs along its bar at the screen side")
    func handleRunsAlongTheBar() {
        let spec = spec()
        #expect(spec.frame.minX == 300 && spec.frame.width == 400)
        #expect(spec.frame.minY == ShelfHandleSpec.inset)
        #expect(spec.frame.height == ShelfHandleSpec.depth)
        // Its hover band starts at the edge itself, past the inset,
        // and runs the same run `hoverDepth` in (#3360).
        #expect(spec.hoverBand.minY == 0)
        #expect(spec.hoverBand.minX == 300 && spec.hoverBand.width == 400)
        #expect(spec.hoverBand.height == ShelfHandleSpec.hoverDepth)
    }

    @Test("the approach reaches 24 pt in and past the run's ends")
    func approachAboutTheHandle() {
        let spec = spec()
        let approach = target(spec).approach ?? .null
        let side =
            GeometryUtils.flip(
                spec.frame,
                primaryHeight: GeometryUtils.primaryHeight
            ).maxY + ShelfHandleSpec.inset
        #expect(approach.minY == side - ShelfReveal.approachReach)
        #expect(approach.maxY == side + ShelfReveal.overshoot)
        #expect(approach.minX == 300 - ShelfReveal.alongReach)
        #expect(approach.maxX == 700 + ShelfReveal.alongReach)
        #expect(target(spec).handle?.width == spec.hoverBand.width)
        #expect(target(spec).handle?.maxY == side)
        #expect(target(spec).handle?.height == ShelfHandleSpec.hoverDepth)
        // Over a maximized window: only to the hover band.
        let inward = (target(spec, maximized: true).approach ?? .null).minY
        #expect(side - inward == ShelfHandleSpec.hoverDepth)
        // On a side edge across x: only the band's depth, never the run.
        let left = ShelfHandleSpec(
            frame: ShelfHandleSpec.frame(
                along: CGRect(x: 0, y: 300, width: 30, height: 400),
                edge: .left,
                side: 0
            ),
            edge: .left,
            shown: false,
            reveal: .slide
        )
        let reach = target(left, maximized: true).approach?.maxX
        #expect(reach == ShelfHandleSpec.hoverDepth)
        // Cut where a sibling's approach meets it.
        let cut = target(spec, cut: (true, true)).approach
        #expect(cut?.minX == 300)
        #expect(cut?.maxX == 700)
    }

    @Test("a shown bar is held over its section, never the edge")
    func holdIsTheSection() {
        let section = CGRect(x: 300, y: 760, width: 400, height: 40)
        let target = ShelfRevealer.Target.along(
            section,
            edge: .top,
            side: 800,
            screen: Self.screen,
            section: section
        )
        let (revealer, box) = make([Self.key: target])
        move(revealer, box, 500, 800)
        #expect(revealer.reveal(of: Self.key) == .hover)
        move(revealer, box, 320, 780)
        #expect(box.delays.isEmpty)
        // Along the edge past the bar: the retract runs.
        move(revealer, box, 900, 780)
        #expect(box.delays == [ShelfReveal.retractDelay])
    }

    /// Two handles on one edge: the Space Bar's run left of the
    /// middle, the App Bar's right of it, their approaches meeting.
    private func pair() -> (ShelfRevealer, Box, ShelfRevealer.Key) {
        let app = ShelfRevealer.Key(shelf: Self.key.shelf, bar: .app)
        // The two approaches overlap by 40 pt, so only the
        // revealer's `yields` keeps a push there to one bar.
        let target = { (minX: CGFloat) in
            ShelfRevealer.Target.along(
                CGRect(
                    x: minX + ShelfReveal.alongReach,
                    y: 790,
                    width: 220 - 2 * ShelfReveal.alongReach,
                    height: 3
                ),
                edge: .top,
                side: 800,
                strip: Self.strip,
                screen: Self.screen
            )
        }
        let (revealer, box) = make([
            Self.key: target(300), app: target(480),
        ])
        return (revealer, box, app)
    }

    @Test("crossing into a sibling's part restarts the fill for it")
    func crossingRestartsTheFill() {
        let app = ShelfRevealer.Key(shelf: Self.key.shelf, bar: .app)
        // Two runs meeting at x 500, their approaches cut there.
        let target = { (minX: CGFloat, cut: (lead: Bool, trail: Bool)) in
            ShelfRevealer.Target.along(
                CGRect(x: minX, y: 797, width: 200, height: 3),
                edge: .top,
                side: 800,
                strip: Self.strip,
                screen: Self.screen,
                handle: CGRect(x: minX, y: 791, width: 200, height: 9),
                cut: cut
            )
        }
        let (revealer, box) = make([
            Self.key: target(300, (false, true)),
            app: target(500, (true, false)),
        ])
        // Inside the sibling's un-cut reach, so the cut decides.
        move(revealer, box, 495, 785)
        #expect(revealer.fills[Self.key]?.origin == 0.975)
        #expect(revealer.fills[app] == nil)
        move(revealer, box, 505, 785)
        #expect(revealer.fills[Self.key] == nil)
        // At its own point nearest the pointer, not the first bar's.
        #expect(revealer.fills[app]?.origin == 0.025)
    }

    @Test("a sibling shown stands a hidden bar's approach down")
    func siblingShownYields() {
        let (revealer, box, app) = pair()
        move(revealer, box, 400, 795)
        #expect(revealer.fills[Self.key] != nil)
        #expect(revealer.toggle(app, duration: 0))
        #expect(revealer.yields(Self.key))
        move(revealer, box, 401, 795)
        #expect(revealer.fills[Self.key] == nil)
        // The dwell it had armed reveals nothing.
        box.timers.forEach { $0() }
        #expect(revealer.reveal(of: Self.key) == .hidden)
        #expect(!revealer.yields(app))
    }

    @Test("a push where two approaches meet opens one bar")
    func seamPushOpensOne() {
        let (revealer, box, app) = pair()
        move(revealer, box, 500, 800)
        let shown = [Self.key, app].filter {
            revealer.reveal(of: $0).isShown
        }
        #expect(shown.count == 1)
    }
}
