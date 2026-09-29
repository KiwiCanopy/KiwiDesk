import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The strip hold as wired (#1528 item 21): a chip's pointer
/// report reaches `SpaceBarManager` through a real overlay, and
/// every way the chip can stop drawing the held Space — the
/// pointer leaving, another chip taking the pointer, the slot
/// drawing another Space, the Space leaving the bar — ends the
/// hold.
@Suite("Space Bar strip hold", .serialized)
@MainActor
struct SpaceBarStripHoldTests {
    private let display = DisplayID(7)
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    private func item(
        _ space: SpaceID,
        window: Range<Int> = 2..<7
    ) -> SpaceBarOverlay.Item {
        SpaceBarOverlay.Item(
            space: space,
            spaceGlyph: .text(space.raw, tinted: true),
            apps: [],
            active: space == one,
            after: .none,
            drawn: .init(window: window, count: 9)
        )
    }

    private func bar(_ items: [SpaceBarOverlay.Item]) -> SpaceBarManager.Bar {
        SpaceBarManager.Bar(
            display: display,
            items: items,
            strip: CGRect(x: 0, y: 0, width: 800, height: 32),
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
    }

    private func view(
        _ manager: SpaceBarManager,
        at index: Int
    ) throws -> SpaceBarItemView {
        let overlay = try #require(manager.overlayForTesting(display))
        return try #require(overlay.itemViews[safe: index])
    }

    @Test("the chip's report holds its strip until the pointer leaves")
    func pointerRoundTrip() throws {
        let manager = SpaceBarManager()
        var released = 0
        manager.onStripReleased = { released += 1 }
        manager.sync([bar([item(one), item(two)])])
        let chip = try view(manager, at: 0)
        chip.setPointerInside(true)
        #expect(
            manager.heldStrip(of: one) == .init(window: 2..<7, count: 9)
        )
        #expect(released == 0)
        chip.setPointerInside(false)
        #expect(manager.heldStrip(of: one) == nil)
        #expect(released == 1)
    }

    @Test("a slot that draws another Space releases the old hold")
    func reusedSlotReleases() throws {
        let manager = SpaceBarManager()
        var released = 0
        manager.onStripReleased = { released += 1 }
        manager.sync([bar([item(one), item(two)])])
        try view(manager, at: 0).setPointerInside(true)
        // The row reorders: slot 0 now draws Space 2.
        manager.sync([bar([item(two), item(one)])])
        #expect(manager.heldStrip(of: one) == nil)
        #expect(released == 1)
    }

    /// Another chip's entry can arrive ahead of the first chip's
    /// exit; the replaced hold still asks for its re-centring.
    @Test("a hold replaced by another Space's releases")
    func replacedHoldReleases() {
        let manager = SpaceBarManager()
        var released = 0
        manager.onStripReleased = { released += 1 }
        let drawn = SpaceBarStrip.Drawn(window: 2..<7, count: 9)
        manager.stripHover(one, drawn, inside: true)
        manager.stripHover(one, drawn, inside: true)
        #expect(released == 0)
        manager.stripHover(two, drawn, inside: true)
        #expect(released == 1)
        #expect(manager.heldStrip(of: one) == nil)
        #expect(manager.heldStrip(of: two) == drawn)
    }

    @Test("a hold on a Space no bar draws is dropped")
    func undrawnSpaceDropsTheHold() {
        let manager = SpaceBarManager()
        manager.sync([bar([item(one), item(two)])])
        manager.stripHover(
            one,
            .init(window: 2..<7, count: 9),
            inside: true
        )
        manager.sync([bar([item(two)])])
        #expect(manager.heldStrip(of: one) == nil)
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
