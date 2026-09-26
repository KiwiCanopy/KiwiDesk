import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space run's glide as wired (#1683): two `sync`s across a
/// Space switch, each frame write recorded through the overlay's
/// `moveFrame` seam. A switch under a collapsing content asks
/// the run to travel; `.apps` and a steady re-render do not; and
/// under Boxed + Liquid Glass the glass travels with its item,
/// which rides it rather than moving on its own.
@Suite("Space bar glide wiring", .serialized)
@MainActor
struct SpaceBarGlideWiringTests {
    private static var platformGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// The writes of the second of two syncs, `from` → `to`.
    private func secondPass(
        _ content: SpaceBarStyle.InactiveContent,
        from: Int,
        to: Int,
        boxedGlass: Bool = false
    ) throws -> (
        writes: [(view: NSView, travels: Bool)],
        overlay: SpaceBarOverlay
    ) {
        LiquidGlassGate.override = { false }
        let manager = SpaceBarManager()
        manager.sync([
            collapsedBar(content, active: from, boxedGlass: boxedGlass)
        ])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        var writes: [(view: NSView, travels: Bool)] = []
        overlay.moveFrame = { view, _, travels in
            writes.append((view, travels))
        }
        manager.sync([
            collapsedBar(content, active: to, boxedGlass: boxedGlass)
        ])
        return (writes, overlay)
    }

    @Test("A switch under Minimal asks the run to travel")
    func switchTravels() throws {
        let (writes, overlay) = try secondPass(.identifier, from: 1, to: 2)
        #expect(writes.count == 3)
        #expect(writes.allSatisfy { $0.travels })
        #expect(overlay.shownExpanded == SpaceID("2"))
    }

    @Test("Apps and a steady render land")
    func othersLand() throws {
        let apps = try secondPass(.apps, from: 1, to: 2).writes
        #expect(!apps.isEmpty)
        #expect(!apps.contains { $0.travels })
        let steady = try secondPass(.count, from: 1, to: 1).writes
        #expect(!steady.isEmpty)
        #expect(!steady.contains { $0.travels })
    }

    /// A hidden bar forgets what it expanded, so it reappears
    /// rather than gliding from a stale Space.
    @Test("A hide forgets the expanded Space")
    func hideForgets() throws {
        let (_, overlay) = try secondPass(.identifier, from: 1, to: 2)
        overlay.hide()
        #expect(overlay.shownExpanded == nil)
        #expect(overlay.shownIdentities.isEmpty)
    }

    /// Hosted items ride their glass: the render moves none of
    /// them, and the glass pass is asked to travel with the run.
    @Test("Box glass travels with its item")
    func boxGlassTravels() throws {
        try #require(Self.platformGlass)
        let (writes, overlay) = try secondPass(
            .identifier,
            from: 1,
            to: 2,
            boxedGlass: true
        )
        #expect(overlay.boxGlasses.count == 3)
        #expect(writes.isEmpty)
        #expect(overlay.boxGlassGlided)
        let steady = try secondPass(
            .identifier,
            from: 2,
            to: 2,
            boxedGlass: true
        ).overlay
        #expect(!steady.boxGlassGlided)
    }
}
