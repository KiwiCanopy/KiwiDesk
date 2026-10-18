import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A hiding shelf's reveal (#761), driven by hand: the pointer is
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

    private static let key = ShelfManager.Key(
        display: DisplayID(1),
        edge: .top
    )
    /// A top shelf 40 pt deep under a 25 pt menu bar on a
    /// 1000 x 800 screen, Cocoa coordinates.
    private static let underMenuBar = ShelfRevealer.Target(
        edge: .top,
        strip: CGRect(x: 0, y: 735, width: 1000, height: 40),
        screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
        bars: [.space]
    )
    /// The same shelf flush with the screen's top.
    private static let flush = ShelfRevealer.Target(
        edge: .top,
        strip: CGRect(x: 0, y: 760, width: 1000, height: 40),
        screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
        bars: [.space]
    )

    private func make(
        _ target: ShelfRevealer.Target = underMenuBar
    ) -> (ShelfRevealer, Timers, Box) {
        let revealer = ShelfRevealer()
        let timers = Timers()
        let pointer = Box()
        revealer.makeMonitor = { _ in nil }
        revealer.location = { pointer.point }
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
    }

    private func move(
        _ revealer: ShelfRevealer,
        _ pointer: Box,
        to point: CGPoint
    ) {
        pointer.point = point
        revealer.moved(to: point)
    }

    @Test("Resting in the band reveals after the delay")
    func bandRevealsAfterDelay() {
        let (revealer, timers, pointer) = make()
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        #expect(revealer.reveal(of: Self.key) == .hidden)
        #expect(timers.delays == [ShelfReveal.revealDelay])
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("Moving inside the band does not restart the delay")
    func jitterKeepsTheDelay() {
        let (revealer, timers, pointer) = make()
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        move(revealer, pointer, to: CGPoint(x: 503, y: 771))
        move(revealer, pointer, to: CGPoint(x: 498, y: 769))
        #expect(timers.delays.count == 1)
    }

    @Test("Leaving the band cancels the reveal")
    func leavingCancels() {
        let (revealer, timers, pointer) = make()
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        move(revealer, pointer, to: CGPoint(x: 500, y: 400))
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("A pointer passing below the band never reveals")
    func stripBelowBandIsNoTarget() {
        let (revealer, timers, pointer) = make()
        // Inside the strip, below the 8 pt band.
        move(revealer, pointer, to: CGPoint(x: 500, y: 745))
        #expect(timers.delays.isEmpty)
    }

    @Test("A push against the screen edge reveals at once")
    func pushRevealsAtOnce() {
        let (revealer, timers, pointer) = make(Self.flush)
        move(revealer, pointer, to: CGPoint(x: 500, y: 800))
        #expect(revealer.reveal(of: Self.key) == .hover)
        #expect(timers.delays.isEmpty)
    }

    @Test("No push where a menu bar stands between")
    func noPushUnderMenuBar() {
        #expect(
            !ShelfReveal.pushes(
                CGPoint(x: 500, y: 775),
                strip: Self.underMenuBar.strip,
                edge: .top,
                screen: Self.underMenuBar.screen
            )
        )
    }

    @Test("Leaving a hover reveal retracts after the delay")
    func hoverRetracts() {
        let (revealer, timers, pointer) = make()
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        timers.fireAll()
        move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        #expect(timers.delays == [ShelfReveal.retractDelay])
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("Coming back inside the retract delay keeps the shelf")
    func returnCancelsRetract() {
        let (revealer, timers, pointer) = make()
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        timers.fireAll()
        move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        move(revealer, pointer, to: CGPoint(x: 500, y: 750))
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("The retract reads a pointer the monitor could not hear")
    func retractRereadsThePointer() {
        let (revealer, timers, pointer) = make()
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        timers.fireAll()
        move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        // Back over the shelf, unheard: over our own panel.
        pointer.point = CGPoint(x: 500, y: 750)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("The action pins until the next press")
    func togglePins() {
        let (revealer, timers, pointer) = make()
        #expect(revealer.toggle(Self.key, duration: 0))
        #expect(revealer.reveal(of: Self.key) == .pinned(until: nil))
        #expect(timers.delays.isEmpty)
        // The pointer leaving changes nothing.
        move(revealer, pointer, to: CGPoint(x: 10, y: 10))
        #expect(revealer.reveal(of: Self.key).isShown)
        revealer.toggle(Self.key, duration: 0)
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("A timed pin hides by itself, or at once on a press")
    func timedPin() {
        let (revealer, timers, pointer) = make()
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
        let (revealer, timers, pointer) = make()
        revealer.toggle(Self.key, duration: 3)
        pointer.point = CGPoint(x: 500, y: 750)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("A press hiding the shelf under the pointer holds the hover")
    func toggleHideSuppressesHover() {
        let (revealer, timers, pointer) = make()
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        timers.fireAll()
        revealer.toggle(Self.key, duration: 0)
        #expect(revealer.reveal(of: Self.key) == .hidden)
        move(revealer, pointer, to: CGPoint(x: 501, y: 770))
        #expect(timers.delays.isEmpty)
        move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        #expect(timers.delays == [ShelfReveal.revealDelay])
    }

    @Test("A show reports a change; a shelf that stops hiding forgets")
    func changesAndForgetting() {
        let (revealer, _, pointer) = make()
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
        let (revealer, timers, pointer) = make(Self.flush)
        move(revealer, pointer, to: CGPoint(x: 500, y: 800))
        move(revealer, pointer, to: CGPoint(x: 520, y: 800))
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("A press that shows the shelf ends an earlier suppression")
    func showClearsSuppression() {
        let (revealer, timers, pointer) = make()
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        timers.fireAll()
        revealer.toggle(Self.key, duration: 0)
        revealer.toggle(Self.key, duration: 2)
        pointer.point = CGPoint(x: 500, y: 750)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
        move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        #expect(timers.delays == [ShelfReveal.retractDelay])
    }

    @Test("Stopping ends every reveal, silently")
    func stopEndsReveals() {
        let (revealer, timers, pointer) = make()
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
        let (revealer, timers, _) = make()
        var holding = true
        revealer.holds = { _ in holding }
        revealer.toggle(Self.key, duration: 3)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
        holding = false
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("An open bar menu or peek holds a retract")
    func holdDefersTheRetract() {
        let (revealer, timers, pointer) = make()
        var holding = true
        revealer.holds = { _ in holding }
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        timers.fireAll()
        move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hover)
        holding = false
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
    }

    @Test("The band arms the mark's hover until the reveal or a leave")
    func armingShowsTheHover() {
        let (revealer, timers, pointer) = make()
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        #expect(revealer.arming == [Self.key])
        move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        #expect(revealer.arming.isEmpty)
        move(revealer, pointer, to: CGPoint(x: 500, y: 770))
        timers.fireAll()
        #expect(revealer.arming.isEmpty)
        #expect(revealer.reveal(of: Self.key) == .hover)
    }

    @Test("Near the mark lights its cue; only the band opens the shelf")
    func nearLightsTheCue() {
        let target = ShelfRevealer.Target(
            edge: .top,
            strip: Self.underMenuBar.strip,
            screen: Self.underMenuBar.screen,
            bars: [.space],
            near: CGRect(x: 400, y: 700, width: 200, height: 75)
        )
        let (revealer, timers, pointer) = make(target)
        move(revealer, pointer, to: CGPoint(x: 500, y: 720))
        #expect(revealer.arming == [Self.key])
        #expect(timers.delays.isEmpty)
        timers.fireAll()
        #expect(revealer.reveal(of: Self.key) == .hidden)
        move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        #expect(revealer.arming.isEmpty)
    }
}
