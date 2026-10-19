import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A press on a hiding shelf's mark acts on the whole shelf in one
/// direction (#761): with any bar shown it hides them all, never
/// swapping one for its sibling, and otherwise shows them all —
/// a band-less (`hidden`) bar is no part of it.
@Suite("Shelf mark press (#761)")
@MainActor
struct ShelfRevealShelfPressTests {
    private static let shelf = ShelfManager.Key(
        display: DisplayID(1),
        edge: .top
    )

    private func make() -> ShelfRevealer {
        let revealer = ShelfRevealer()
        revealer.makeMonitor = { _ in nil }
        revealer.schedule = { _, _ in ShelfRevealTimer() }
        revealer.location = { CGPoint(x: 500, y: 300) }
        let strip = CGRect(x: 0, y: 760, width: 1000, height: 40)
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        revealer.sync([
            .init(shelf: Self.shelf, bar: .space): .hovering(
                edge: .top,
                strip: strip,
                screen: screen
            ),
            .init(shelf: Self.shelf, bar: .app): .hovering(
                edge: .top,
                strip: strip,
                screen: screen
            ),
        ])
        return revealer
    }

    private func shown(_ revealer: ShelfRevealer, _ bar: ShelfBar) -> Bool {
        revealer.reveal(of: .init(shelf: Self.shelf, bar: bar)).isShown
    }

    @Test("a press hides every bar while one shows, then shows both")
    func pressActsOnTheShelf() {
        let revealer = make()
        revealer.start()
        defer { revealer.stop() }
        revealer.toggle(.init(shelf: Self.shelf, bar: .space), duration: 0)
        #expect(shown(revealer, .space))
        #expect(!shown(revealer, .app))
        revealer.toggleShelf(Self.shelf, duration: 0)
        #expect(!shown(revealer, .space))
        #expect(!shown(revealer, .app))
        revealer.toggleShelf(Self.shelf, duration: 0)
        #expect(shown(revealer, .space))
        #expect(shown(revealer, .app))
    }
}
