import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An Auto bar's approach (#3349), on `ShelfRevealerTests`' fixture
/// and hand-fired timers: the handle thickens after the approach's
/// wait, the bar opens on the dwell, on the thickened handle or on
/// a push against a free edge, and an edge macOS owns takes the
/// push for itself.
@Suite("Shelf approach (#3349)")
@MainActor
struct ShelfRevealApproachTests {
    typealias Suite = ShelfRevealerTests

    /// The approach's wait, then the dwell's rest from the entry.
    private var dwell: [TimeInterval] {
        [ShelfReveal.dwellDelay - ShelfReveal.approachDelay]
    }

    @Test("Approach thickens the handle, then the dwell opens the bar")
    func approachThenDwell() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        #expect(timers.delays == [ShelfReveal.approachDelay])
        #expect(revealer.arming.isEmpty)
        timers.fireAll()
        #expect(revealer.arming == [Suite.key])
        #expect(revealer.reveal(of: Suite.key) == .hidden)
        #expect(timers.delays == dwell)
        timers.fireAll()
        #expect(revealer.reveal(of: Suite.key) == .hover)
        #expect(revealer.arming.isEmpty)
    }

    @Test("Resting on the thickened handle opens after the delay")
    func handleOpens() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 768))
        timers.fireAll()
        // The approach fired: the dwell and the handle's delay run.
        #expect(
            timers.delays.sorted()
                == (dwell + [ShelfReveal.revealDelay]).sorted()
        )
        timers.queue.removeAll { $0.delay != ShelfReveal.revealDelay }
        timers.fireAll()
        #expect(revealer.reveal(of: Suite.key) == .hover)
    }

    @Test("Moving inside the approach does not restart the wait")
    func jitterKeepsTheDelay() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        Suite.move(revealer, pointer, to: CGPoint(x: 503, y: 756))
        Suite.move(revealer, pointer, to: CGPoint(x: 498, y: 754))
        #expect(timers.delays.count == 1)
    }

    @Test("Leaving the approach cancels every wait")
    func leavingCancels() {
        let (revealer, timers, pointer) = Suite.make()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 755))
        timers.fireAll()
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 400))
        #expect(revealer.arming.isEmpty)
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
        timers.fireAll()
        #expect(revealer.arming == [Suite.key])
        // The push: every wait ends, the handle rests.
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 800))
        #expect(revealer.reveal(of: Suite.key) == .hidden)
        #expect(revealer.ceded == [Suite.key])
        #expect(revealer.arming.isEmpty)
        timers.fireAll()
        #expect(revealer.reveal(of: Suite.key) == .hidden)
        // However long the pointer then stays inside.
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 785))
        #expect(timers.delays.isEmpty)
        // Leaving and coming back re-arms the approach.
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 400))
        #expect(revealer.ceded.isEmpty)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 785))
        #expect(timers.delays == [ShelfReveal.approachDelay])
    }

    @Test("Lingering just inside an edge macOS owns opens only the bar")
    func macOSEdgeDwellOpens() {
        let (revealer, timers, pointer) = Suite.make(Suite.flush)
        pointer.edges = MacEdges(dock: nil, menuBar: true)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 794))
        timers.fireAll()
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
    /// window — ends the thickening when the dwell runs out.
    @Test("an unheard leave ends the thickening at the dwell")
    func unheardLeaveEndsTheThickening() {
        let (revealer, timers, pointer) = Suite.make(Suite.flush)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 785))
        timers.fireAll()
        #expect(revealer.arming == [Suite.key])
        pointer.point = CGPoint(x: 500, y: 300)
        timers.fireAll()
        #expect(revealer.arming.isEmpty)
        #expect(revealer.reveal(of: Suite.key) == .hidden)
    }
}
