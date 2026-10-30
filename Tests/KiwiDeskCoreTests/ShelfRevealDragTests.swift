import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A window drag opens an Auto Space Bar, its drop targets (#2795):
/// a dragged pointer pushing the edge or dwelling in the band
/// reveals it, the App Bar stays hidden, and a drag-born reveal
/// retracts as a hover reveal does. Every move arrives through the
/// monitor's own delivery, so the drag flag's wiring is read too.
@Suite("Shelf reveal on a drag (#2795)")
@MainActor
struct ShelfRevealDragTests {
    final class Rig {
        let revealer = ShelfRevealer()
        var point = CGPoint(x: 500, y: 400)
        var deliver: ((CGPoint?, Bool) -> Void)?
        var timers: [(delay: TimeInterval, body: () -> Void)] = []

        var delays: [TimeInterval] { timers.map(\.delay) }

        func fireAll() {
            let due = timers
            timers = []
            for timer in due { timer.body() }
        }

        /// One pointer event at `point`, a left drag or a move.
        func send(_ point: CGPoint, dragging: Bool) {
            self.point = point
            deliver?(point, dragging)
        }
    }

    private static let screen = CGRect(
        x: 0,
        y: 0,
        width: 1000,
        height: 800
    )
    private static let space = ShelfRevealer.Key(
        shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
        bar: .space
    )
    private static let app = ShelfRevealer.Key(
        shelf: ShelfManager.Key(display: DisplayID(1), edge: .bottom),
        bar: .app
    )
    /// The Space Bar's shelf flush with the screen's top.
    private static let top = ShelfRevealer.Target.hovering(
        edge: .top,
        strip: CGRect(x: 0, y: 760, width: 1000, height: 40),
        screen: screen,
        section: CGRect(x: 350, y: 760, width: 300, height: 40)
    )
    /// The App Bar's shelf on the screen's bottom.
    private static let bottom = ShelfRevealer.Target.hovering(
        edge: .bottom,
        strip: CGRect(x: 0, y: 0, width: 1000, height: 40),
        screen: screen,
        section: CGRect(x: 350, y: 0, width: 300, height: 40)
    )

    private func make(
        _ targets: [ShelfRevealer.Key: ShelfRevealer.Target] = [
            space: top, app: bottom,
        ]
    ) -> Rig {
        let rig = Rig()
        rig.revealer.makeMonitor = { deliver in
            rig.deliver = deliver
            return [Any]()
        }
        rig.revealer.removeMonitor = { _ in }
        rig.revealer.location = { rig.point }
        rig.revealer.schedule = { delay, body in
            rig.timers.append((delay, body))
            return ShelfRevealTimer()
        }
        rig.revealer.sync(targets)
        rig.revealer.start()
        return rig
    }

    @Test("the monitor hears a left drag beside a move")
    func hearsTheDrag() {
        #expect(ShelfRevealer.heard.contains(.leftMouseDragged))
        #expect(ShelfRevealer.heard.contains(.mouseMoved))
    }

    @Test("a drag pushing the edge reveals the Space Bar at once")
    func dragPushReveals() {
        let rig = make()
        defer { rig.revealer.stop() }
        rig.send(CGPoint(x: 500, y: 800), dragging: true)
        #expect(rig.revealer.reveal(of: Self.space) == .hover)
        #expect(rig.timers.isEmpty)
    }

    @Test("a drag resting in the band reveals after the delay")
    func dragDwellReveals() {
        let rig = make()
        defer { rig.revealer.stop() }
        rig.send(CGPoint(x: 500, y: 795), dragging: true)
        #expect(rig.revealer.reveal(of: Self.space) == .hidden)
        #expect(rig.delays == [ShelfReveal.revealDelay])
        rig.fireAll()
        #expect(rig.revealer.reveal(of: Self.space) == .hover)
    }

    /// The control half: the same push without the button reveals
    /// the App Bar, so the drag alone is what refuses it.
    @Test("a drag never opens the App Bar")
    func dragLeavesTheAppBar() {
        let rig = make()
        defer { rig.revealer.stop() }
        rig.send(CGPoint(x: 500, y: 2), dragging: true)
        rig.send(CGPoint(x: 500, y: 0), dragging: true)
        #expect(rig.revealer.reveal(of: Self.app) == .hidden)
        #expect(rig.timers.isEmpty)
        #expect(!rig.revealer.arming.contains(Self.app))
        rig.send(CGPoint(x: 500, y: 0), dragging: false)
        #expect(rig.revealer.reveal(of: Self.app) == .hover)
    }

    @Test("a hidden Space Bar stays hidden under a drag")
    func dragLeavesAHiddenBar() {
        let hidden = ShelfRevealer.Target(
            edge: .top,
            strip: Self.top.strip,
            screen: Self.screen,
            band: nil
        )
        let rig = make([Self.space: hidden, Self.app: Self.bottom])
        defer { rig.revealer.stop() }
        rig.send(CGPoint(x: 500, y: 800), dragging: true)
        rig.send(CGPoint(x: 500, y: 795), dragging: true)
        rig.fireAll()
        #expect(rig.revealer.reveal(of: Self.space) == .hidden)
    }

    /// A drop on the bar keeps it, as a hover does; a drop or a
    /// drag elsewhere retracts it after the delay.
    @Test("a drag-born reveal retracts once the drag leaves it")
    func dragRevealRetracts() {
        let rig = make()
        defer { rig.revealer.stop() }
        rig.send(CGPoint(x: 500, y: 800), dragging: true)
        rig.send(CGPoint(x: 520, y: 780), dragging: true)
        #expect(rig.timers.isEmpty)
        rig.send(CGPoint(x: 500, y: 400), dragging: true)
        #expect(rig.delays == [ShelfReveal.retractDelay])
        rig.fireAll()
        #expect(rig.revealer.reveal(of: Self.space) == .hidden)
    }

    @Test("a drag leaving a shown App Bar retracts it")
    func dragRetractsTheAppBar() {
        let rig = make()
        defer { rig.revealer.stop() }
        rig.send(CGPoint(x: 500, y: 0), dragging: false)
        #expect(rig.revealer.reveal(of: Self.app) == .hover)
        rig.send(CGPoint(x: 500, y: 400), dragging: true)
        #expect(rig.delays == [ShelfReveal.retractDelay])
        rig.fireAll()
        #expect(rig.revealer.reveal(of: Self.app) == .hidden)
    }
}
