import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The tour's looks step holds every hiding bar shown (#2515), so
/// a look is painted onto bars the user can see: the hold reads
/// over the pointer's state and the shortcut's, and lets them
/// stand again on release.
@Suite("Shelf reveal hold (#2515)")
@MainActor
struct ShelfRevealHoldTests {
    private static let key = ShelfRevealer.Key(
        shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
        bar: .space
    )
    private static let other = ShelfRevealer.Key(
        shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
        bar: .app
    )
    private static let target = ShelfRevealer.Target.hovering(
        edge: .top,
        strip: CGRect(x: 0, y: 735, width: 1000, height: 40),
        screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
        section: CGRect(x: 350, y: 735, width: 300, height: 40)
    )

    private func make() -> (ShelfRevealer, Counter) {
        let revealer = ShelfRevealer()
        let counter = Counter()
        revealer.makeMonitor = { _ in nil }
        revealer.location = { CGPoint(x: 500, y: 300) }
        revealer.schedule = { _, _ in ShelfRevealTimer(onCancel: {}) }
        revealer.onChange = { counter.changes += 1 }
        revealer.sync([Self.key: Self.target])
        revealer.start()
        return (revealer, counter)
    }

    final class Counter {
        var changes = 0
    }

    @Test("a hold shows every hiding bar and redraws once")
    func holdShowsHidingBars() {
        let (revealer, counter) = make()
        #expect(revealer.reveal(of: Self.key) == .hidden)
        revealer.heldOpen = true
        #expect(revealer.reveal(of: Self.key).isShown)
        #expect(counter.changes == 1)
        revealer.heldOpen = true
        #expect(counter.changes == 1)
    }

    /// A bar that does not hide has no target, and the hold
    /// invents no reveal for it.
    @Test("a hold reaches only the hiding bars")
    func holdSkipsNonTargets() {
        let (revealer, _) = make()
        revealer.heldOpen = true
        #expect(revealer.reveal(of: Self.other) == .hidden)
    }

    @Test("a release returns what the pointer and shortcut left")
    func releaseRestoresState() {
        let (revealer, counter) = make()
        revealer.heldOpen = true
        revealer.heldOpen = false
        #expect(revealer.reveal(of: Self.key) == .hidden)
        #expect(counter.changes == 2)
        revealer.toggle(Self.key, duration: 0)
        revealer.heldOpen = true
        revealer.heldOpen = false
        #expect(revealer.reveal(of: Self.key) == .pinned(until: nil))
    }

    /// A stop is silent and owes no hold to the next start.
    @Test("a stop releases the hold silently")
    func stopReleases() {
        let (revealer, counter) = make()
        revealer.heldOpen = true
        let before = counter.changes
        revealer.stop()
        #expect(!revealer.heldOpen)
        #expect(counter.changes == before)
    }

    /// Under a hold the bar reads shown whatever its phase, so a
    /// shortcut is refused rather than moving the phase the release
    /// gives back.
    @Test("a toggle under the hold is refused and keeps the phase")
    func toggleUnderHoldIsRefused() {
        let (revealer, _) = make()
        revealer.toggle(Self.key, duration: 0)
        revealer.heldOpen = true
        #expect(!revealer.toggle(Self.key, duration: 0))
        revealer.heldOpen = false
        #expect(revealer.reveal(of: Self.key) == .pinned(until: nil))
    }
}
