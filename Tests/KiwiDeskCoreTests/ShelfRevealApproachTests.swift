import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An Auto bar's approach (#3349, #3360), on `ShelfRevealerTests`'
/// fixture and hand-fired timers: entering the approach starts the
/// fill at the handle's point nearest the pointer, and the bar
/// opens as it completes — the dwell, hurried by a rest on the
/// handle — or at once on a push against a free edge, and an edge
/// macOS owns takes the push for itself.
@Suite("Shelf approach (#3349)")
@MainActor
struct ShelfRevealApproachTests {
    typealias Suite = ShelfRevealerTests

    @Test("The entry starts the fill, and the dwell opens the bar")
    func approachThenDwell() {
        let (revealer, timers, pointer) = Suite.make()
        #expect(revealer.fills.isEmpty)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        #expect(timers.delays == [ShelfReveal.dwellDelay])
        let fill = revealer.fills[Suite.key]
        #expect(fill?.started == pointer.now)
        #expect(abs((fill?.length ?? 0) - ShelfReveal.dwellDelay) < 1e-6)
        #expect(revealer.reveal(of: Suite.key) == .hidden)
        timers.fireAll()
        #expect(revealer.reveal(of: Suite.key) == .hover)
        #expect(revealer.fills.isEmpty)
    }

    @Test("The fill starts nearest the pointer and keeps that start")
    func fillKeepsItsStart() {
        let (revealer, _, pointer) = Suite.make()
        // The handle runs x 347–653: a quarter of the way along.
        Suite.move(revealer, pointer, to: CGPoint(x: 423.5, y: 755))
        let start = revealer.fills[Suite.key]?.origin ?? -1
        #expect(abs(start - 0.25) < 0.001)
        Suite.move(revealer, pointer, to: CGPoint(x: 600, y: 756))
        #expect(revealer.fills[Suite.key]?.origin == start)
        // Past the run's end the start holds at that end.
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 400))
        Suite.move(revealer, pointer, to: CGPoint(x: 340, y: 760))
        #expect(revealer.fills[Suite.key]?.origin == 0)
    }

    @Test("Resting on the handle hurries the fill to the delay")
    func handleOpens() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        let origin = revealer.fills[Suite.key]?.origin
        pointer.now += 0.1
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 768))
        #expect(
            timers.delays.sorted()
                == [ShelfReveal.revealDelay, ShelfReveal.dwellDelay]
        )
        #expect(
            revealer.fills[Suite.key]
                == .init(
                    origin: origin ?? -1,
                    started: pointer.now,
                    until: pointer.now + ShelfReveal.revealDelay
                )
        )
        timers.queue.removeAll { $0.delay != ShelfReveal.revealDelay }
        timers.fireAll()
        #expect(revealer.reveal(of: Suite.key) == .hover)
    }

    @Test("An entry onto the handle itself hurries the fill at once")
    func entryOnTheHandleHurries() {
        let (revealer, timers, pointer) = Suite.make()
        revealer.onChange = { pointer.changes += 1 }
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 768))
        // Set once, so its first draw runs from its start.
        #expect(pointer.changes == 1)
        #expect(
            timers.delays.sorted()
                == [ShelfReveal.revealDelay, ShelfReveal.dwellDelay]
        )
        let length = revealer.fills[Suite.key]?.length ?? 0
        #expect(abs(length - ShelfReveal.revealDelay) < 1e-6)
    }

    @Test("A late rest on the handle never lengthens the fill")
    func lateRestKeepsTheFill() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        let fill = revealer.fills[Suite.key]
        pointer.now += 0.3
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 768))
        #expect(revealer.fills[Suite.key] == fill)
        #expect(timers.delays == [ShelfReveal.dwellDelay])
    }

    @Test("On a side edge the fill starts from the top, AX-wise")
    func sideEdgeOrigin() {
        let target = ShelfRevealer.Target.along(
            CGRect(x: 0, y: 100, width: 3, height: 400),
            edge: .left,
            side: 0,
            screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
            handle: CGRect(x: 0, y: 100, width: 9, height: 400)
        )
        // Cocoa y 400 is a quarter down from the handle's top, 500.
        #expect(target.fillOrigin(at: CGPoint(x: 5, y: 400)) == 0.25)
        #expect(target.fillOrigin(at: CGPoint(x: 5, y: 550)) == 0)
        #expect(target.fillOrigin(at: CGPoint(x: 5, y: 50)) == 1)
    }

    @Test("Moving inside the approach does not restart the fill")
    func jitterKeepsTheDelay() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        Suite.move(revealer, pointer, to: CGPoint(x: 503, y: 756))
        Suite.move(revealer, pointer, to: CGPoint(x: 498, y: 754))
        #expect(timers.delays == [ShelfReveal.dwellDelay])
    }

    @Test("Leaving the approach cancels the fill and the opening")
    func leavingCancels() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 400))
        #expect(revealer.fills.isEmpty)
        timers.fireAll()
        #expect(revealer.reveal(of: Suite.key) == .hidden)
    }

    @Test("Below the approach, or past the run's ends, nothing runs")
    func outsideIsNoTarget() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 745))
        Suite.move(revealer, pointer, to: CGPoint(x: 330, y: 760))
        Suite.move(revealer, pointer, to: CGPoint(x: 670, y: 760))
        #expect(timers.delays.isEmpty)
    }

    @Test("A push on a free edge opens at once, along the whole run")
    func pushRevealsAtOnce() {
        for x: CGFloat in [345, 500, 655] {
            let (revealer, timers, pointer) = Suite.make(Suite.flush)
            Suite.move(revealer, pointer, to: CGPoint(x: x, y: 800))
            #expect(revealer.reveal(of: Suite.key) == .hover)
            #expect(timers.delays.isEmpty)
        }
    }

    @Test("Under a menu bar a push into it opens nothing")
    func pushUnderMenuBarIsNoPush() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 800))
        #expect(revealer.reveal(of: Suite.key) == .hidden)
        #expect(timers.delays.isEmpty)
    }

    @Test("On an edge macOS owns the outermost row hands it over")
    func macOSEdgeCedes() {
        let (revealer, timers, pointer) = Suite.make(Suite.flush)
        pointer.edges = MacEdges(dock: nil, menuBar: true)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 785))
        #expect(revealer.fills[Suite.key] != nil)
        // The push: every wait ends, the handle rests.
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 800))
        #expect(revealer.reveal(of: Suite.key) == .hidden)
        #expect(revealer.ceded == [Suite.key])
        #expect(revealer.fills.isEmpty)
        timers.fireAll()
        #expect(revealer.reveal(of: Suite.key) == .hidden)
        // However long the pointer then stays inside.
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 785))
        #expect(timers.delays.isEmpty)
        // Leaving and coming back re-arms the approach.
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 400))
        #expect(revealer.ceded.isEmpty)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 785))
        #expect(timers.delays == [ShelfReveal.dwellDelay])
    }

    @Test("Lingering just inside an edge macOS owns opens only the bar")
    func macOSEdgeDwellOpens() {
        let (revealer, timers, pointer) = Suite.make(Suite.flush)
        pointer.edges = MacEdges(dock: nil, menuBar: true)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 794))
        timers.fireAll()
        #expect(revealer.reveal(of: Suite.key) == .hover)
    }

    @Test("The Dock's edge belongs to macOS only while it hides")
    func dockEdgeIsRead() {
        let read = { (prefs: [String: Any]) in
            MacEdges.dock { domain, key in
                domain == "com.apple.dock" ? prefs[key] : nil
            }
        }
        let on = NSNumber(value: true)
        #expect(read([:]) == nil)
        #expect(read(["autohide": NSNumber(value: false)]) == nil)
        // A value of another shape reads as macOS's default.
        #expect(read(["autohide": "yes"]) == nil)
        #expect(read(["autohide": on]) == .bottom)
        #expect(read(["autohide": on, "orientation": "left"]) == .left)
        #expect(read(["autohide": on, "orientation": "right"]) == .right)
        #expect(read(["autohide": on, "orientation": "bottom"]) == .bottom)
        let hidden = MacEdges(dock: .bottom)
        #expect(hidden.owns(.bottom))
        #expect(!hidden.owns(.top) && !hidden.owns(.left))
        #expect(MacEdges(dock: nil, menuBar: true).owns(.top))
        #expect(!MacEdges.none.owns(.bottom))
    }

    @Test("macOS's edges are read once per approach")
    func readOncePerApproach() {
        let (revealer, _, pointer) = Suite.make(Suite.flush)
        var reads = 0
        revealer.macEdges = {
            reads += 1
            return .none
        }
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 785))
        Suite.move(revealer, pointer, to: CGPoint(x: 510, y: 786))
        #expect(reads == 1)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 400))
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 785))
        #expect(reads == 2)
    }

    /// A leave the monitor never heard — a drag that moves no
    /// window — ends the fill when the dwell runs out.
    @Test("an unheard leave ends the fill at the dwell")
    func unheardLeaveEndsTheFill() {
        let (revealer, timers, pointer) = Suite.make(Suite.flush)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 785))
        #expect(revealer.fills[Suite.key] != nil)
        pointer.point = CGPoint(x: 500, y: 300)
        timers.fireAll()
        #expect(revealer.fills.isEmpty)
        #expect(revealer.reveal(of: Suite.key) == .hidden)
    }
}
