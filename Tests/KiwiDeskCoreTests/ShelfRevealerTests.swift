import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A hiding shelf's reveal (#761, #3349), driven by hand: the pointer is
/// a stored point, the clock a stored date and every timer a
/// queued call this suite fires, so no wall clock decides a
/// verdict (tests.md ▸ the age-bounded ledger rule).
@Suite("Shelf reveal (#761)")
@MainActor
struct ShelfRevealerTests {
    /// The timers a revealer armed, fired by hand.
    final class Timers {
        var queue: [(delay: TimeInterval, body: () -> Void, live: Bool)] = []

        func fireAll() {
            let due = queue
            queue = []
            for timer in due where timer.live { timer.body() }
        }

        var delays: [TimeInterval] { queue.filter(\.live).map(\.delay) }
    }

    static let key = ShelfRevealer.Key(
        shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
        bar: .space
    )
    /// A top shelf 40 pt deep under a 25 pt menu bar on a
    /// 1000 x 800 screen, Cocoa coordinates, its bar drawing 300 pt
    /// in the middle while shown: the approach runs from y 751 up
    /// to 779 past the shelf's side at 775, the thickened handle
    /// y 764–773.
    static let underMenuBar = target(stripY: 735)
    /// The same shelf flush with the screen's top: side 800,
    /// approach y 776–804, handle y 789–798.
    static let flush = target(stripY: 760)

    static func target(stripY: CGFloat) -> ShelfRevealer.Target {
        let side = stripY + 40
        let run = CGRect(x: 350, y: side - 5, width: 300, height: 3)
        return .along(
            run,
            edge: .top,
            side: side,
            strip: CGRect(x: 0, y: stripY, width: 1000, height: 40),
            screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
            handle: CGRect(x: 347, y: side - 11, width: 306, height: 9),
            section: CGRect(x: 350, y: stripY, width: 300, height: 40)
        )
    }

    static func make(
        _ target: ShelfRevealer.Target = underMenuBar
    ) -> (ShelfRevealer, Timers, Box) {
        let revealer = ShelfRevealer()
        let timers = Timers()
        let pointer = Box()
        revealer.makeMonitor = { _ in nil }
        revealer.location = { pointer.point }
        revealer.macEdges = { pointer.edges }
        revealer.now = { pointer.now }
        revealer.schedule = { delay, body in
            let index = timers.queue.count
            timers.queue.append((delay, body, true))
            return ShelfRevealTimer(onCancel: {
                if index < timers.queue.count {
                    timers.queue[index].live = false
                }
            })
        }
        revealer.sync([Self.key: target])
        return (revealer, timers, pointer)
    }

    final class Box {
        var point = CGPoint(x: 500, y: 300)
        var now = Date(timeIntervalSince1970: 1_000)
        var changes = 0
        /// A bar menu or peek holding the shelf.
        var holding = true
        /// The edges macOS auto-hides something on.
        var edges = MacEdges.none
    }

    static func move(
        _ revealer: ShelfRevealer,
        _ pointer: Box,
        to point: CGPoint
    ) {
        pointer.point = point
        revealer.moved(to: point)
    }

    /// Opens the bar from the approach: its wait, then the dwell.
    static func open(_ revealer: ShelfRevealer, _ timers: Timers) {
        timers.fireAll()
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("Leaving a hover reveal retracts after the delay")
    func hoverRetracts() {
        let (revealer, timers, pointer) = Self.make()
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        Self.open(revealer, timers)
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        #expect(timers.delays == [ShelfReveal.retractDelay])
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("Coming back inside the retract delay keeps the shelf")
    func returnCancelsRetract() {
        let (revealer, timers, pointer) = Self.make()
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        Self.open(revealer, timers)
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 750))
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("The retract reads a pointer the monitor could not hear")
    func retractRereadsThePointer() {
        let (revealer, timers, pointer) = Self.make()
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        Self.open(revealer, timers)
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        // Back over the shelf, unheard: over our own panel.
        pointer.point = CGPoint(x: 500, y: 750)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("The action pins until the next press")
    func togglePins() {
        let (revealer, timers, pointer) = Self.make()
        #expect(revealer.toggle(Self.key, duration: 0))
        #expect(revealer.reveal(of: Self.key) == .pinned(until: nil))
        #expect(timers.delays.isEmpty)
        // The pointer leaving changes nothing.
        Self.move(revealer, pointer, to: CGPoint(x: 10, y: 10))
        #expect(revealer.reveal(of: Self.key).isShown)
        revealer.toggle(Self.key, duration: 0)
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("A timed pin hides by itself, or at once on a press")
    func timedPin() {
        let (revealer, timers, pointer) = Self.make()
        revealer.toggle(Self.key, duration: 10)
        #expect(timers.delays == [10])
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
        revealer.toggle(Self.key, duration: 10)
        pointer.now = pointer.now.addingTimeInterval(5)
        revealer.toggle(Self.key, duration: 10)
        #expect(revealer.reveal(of: Self.key) == .hidden)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("A timed pin under the pointer becomes a hover reveal")
    func timedPinUnderPointer() {
        let (revealer, timers, pointer) = Self.make()
        revealer.toggle(Self.key, duration: 3)
        pointer.point = CGPoint(x: 500, y: 750)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("A press hiding the shelf under the pointer holds the hover")
    func toggleHideSuppressesHover() {
        let (revealer, timers, pointer) = Self.make()
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        Self.open(revealer, timers)
        revealer.toggle(Self.key, duration: 0)
        #expect(revealer.reveal(of: Self.key) == .hidden)
        Self.move(revealer, pointer, to: CGPoint(x: 501, y: 755))
        #expect(timers.delays.isEmpty)
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        #expect(timers.delays == [ShelfReveal.approachDelay])
    }

    @Test("A show reports a change; a shelf that stops hiding forgets")
    func changesAndForgetting() {
        let (revealer, _, pointer) = Self.make()
        revealer.onChange = { pointer.changes += 1 }
        revealer.toggle(Self.key, duration: 0)
        #expect(pointer.changes == 1)
        revealer.sync([:])
        #expect(revealer.reveal(of: Self.key) == .hidden)
        #expect(revealer.targets.isEmpty)
        #expect(!revealer.toggle(Self.key, duration: 0))
    }

    @Test("The monitor listens only while a shelf hides")
    func monitorOnlyWhileHiding() {
        let revealer = ShelfRevealer()
        var installs = 0
        revealer.makeMonitor = { _ in
            installs += 1
            return [Any]()
        }
        revealer.removeMonitor = { _ in }
        revealer.start()
        #expect(!revealer.isListening)
        revealer.sync([Self.key: Self.flush])
        #expect(revealer.isListening)
        revealer.sync([:])
        #expect(!revealer.isListening)
        #expect(installs == 1)
    }

    @Test("A pointer resting on the screen's last row keeps the shelf")
    func lastRowIsInside() {
        let (revealer, timers, pointer) = Self.make(Self.flush)
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 800))
        Self.move(revealer, pointer, to: CGPoint(x: 520, y: 800))
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("A press that shows the shelf ends an earlier suppression")
    func showClearsSuppression() {
        let (revealer, timers, pointer) = Self.make()
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        Self.open(revealer, timers)
        revealer.toggle(Self.key, duration: 0)
        revealer.toggle(Self.key, duration: 2)
        pointer.point = CGPoint(x: 500, y: 750)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        #expect(timers.delays == [ShelfReveal.retractDelay])
    }

    @Test("Stopping ends every reveal, silently")
    func stopEndsReveals() {
        let (revealer, timers, pointer) = Self.make()
        revealer.onChange = { pointer.changes += 1 }
        revealer.toggle(Self.key, duration: 5)
        revealer.stop()
        #expect(revealer.reveal(of: Self.key) == .hidden)
        // The core is tearing its bars down; no redraw rides it.
        #expect(pointer.changes == 1)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("A timed pin under an open menu waits for it")
    func pinWaitsForTheMenu() {
        let (revealer, timers, pointer) = Self.make()
        revealer.holds = { _ in pointer.holding }
        revealer.toggle(Self.key, duration: 3)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
        pointer.holding = false
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("An open bar menu or peek holds a retract")
    func holdDefersTheRetract() {
        let (revealer, timers, pointer) = Self.make()
        revealer.holds = { _ in pointer.holding }
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        Self.open(revealer, timers)
        Self.move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
        pointer.holding = false
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }
}
