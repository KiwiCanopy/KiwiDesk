import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket's handle is a member of the revealer beside the bars
/// (#3368): it shares the approach, and stays out of what belongs to
/// the bars alone — yielding, the shelf's panel, the tour's hold.
@Suite("Shelf reveal pocket key (#3368)")
@MainActor
struct ShelfRevealPocketKeyTests {
    typealias Suite = ShelfRevealerTests

    private let pocket = ShelfRevealer.Key.pocket(on: Suite.key.shelf)

    @Test("a risen pocket stands no bar aside, nor yields to one")
    func noYield() {
        let (revealer, _, _) = Suite.make()
        revealer.sync([Suite.key: Suite.underMenuBar, pocket: Suite.flush])
        revealer.set(.hover, for: pocket)
        #expect(!revealer.yields(Suite.key))
        revealer.set(.hidden, for: pocket)
        revealer.set(.hover, for: Suite.key)
        #expect(!revealer.yields(pocket))
    }

    @Test("the pocket's target keeps no shelf panel")
    func noShelfTarget() {
        let (revealer, _, _) = Suite.make()
        revealer.sync([pocket: Suite.flush])
        #expect(!revealer.hasTarget(on: Suite.key.shelf))
        revealer.sync([Suite.key: Suite.flush, pocket: Suite.flush])
        #expect(revealer.hasTarget(on: Suite.key.shelf))
    }

    @Test("the tour's hold shows the bars, never the pocket")
    func holdSkipsThePocket() {
        let (revealer, _, _) = Suite.make()
        revealer.sync([Suite.key: Suite.flush, pocket: Suite.flush])
        revealer.heldOpen = true
        #expect(revealer.reveal(of: Suite.key).isShown)
        #expect(!revealer.reveal(of: pocket).isShown)
    }

    @Test("a push on a free edge stands the pocket at once")
    func pushStands() {
        let (revealer, _, pointer) = Suite.make()
        revealer.sync([pocket: Suite.flush])
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 800))
        #expect(revealer.reveal(of: pocket) == .hover)
    }

    @Test("the outermost row of an edge macOS owns cedes the pocket")
    func macOSEdgeCedes() {
        let (revealer, timers, pointer) = Suite.make()
        revealer.sync([pocket: Suite.flush])
        pointer.edges = MacEdges(dock: nil, menuBar: true)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 800))
        #expect(revealer.ceded.contains(pocket))
        #expect(revealer.fills[pocket] == nil)
        timers.fireAll()
        #expect(revealer.reveal(of: pocket) == .hidden)
    }

    @Test("standing a key that held a fill reports the change (#3383)")
    func clearedFillReports() {
        let (revealer, _, _) = Suite.make()
        revealer.sync([pocket: Suite.flush])
        revealer.set(.hover, for: pocket)
        let fill = ShelfHandleSpec.Fill(
            origin: 0.5,
            started: Date(timeIntervalSince1970: 1_000),
            until: Date(timeIntervalSince1970: 1_001)
        )
        revealer.setFill(pocket, fill)
        var changes = 0
        revealer.onChange = { changes += 1 }
        // Shown before and after: only the cleared fill changed.
        revealer.set(.pinned(until: nil), for: pocket)
        #expect(revealer.fills[pocket] == nil)
        #expect(changes == 1)
    }

    @Test("a shelf surface holds the bars, never the pocket")
    func holdSkipsTheRisenPocket() {
        let (revealer, timers, pointer) = Suite.make()
        revealer.sync([Suite.key: Suite.flush, pocket: Suite.flush])
        revealer.holds = { _ in true }
        revealer.set(.hover, for: pocket)
        Suite.move(revealer, pointer, to: CGPoint(x: 500, y: 300))
        timers.fireAll()
        #expect(revealer.reveal(of: pocket) == .hidden)
    }
}
