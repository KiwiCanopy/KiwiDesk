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
        boxedGlass: Bool = false,
        dropEmpty: Bool = false
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
        // The run view carries the scroll, not the glide's items.
        overlay.moveFrame = { [unowned overlay] view, _, travels in
            guard view !== overlay.itemRun else { return }
            writes.append((view, travels))
        }
        // A steady pass repeats its input, which draws nothing
        // since #1901; force the draw it is here to classify.
        if from == to { BarFont.invalidate() }
        var second = collapsedBar(
            content,
            active: to,
            boxedGlass: boxedGlass
        )
        if dropEmpty {
            second = SpaceBarManager.Bar(
                display: second.display,
                items: Array(second.items.dropLast()),
                frontApp: nil,
                frontWindow: nil,
                strip: second.strip,
                style: second.style,
                stateMarkColors: second.stateMarkColors
            )
        }
        manager.sync([second])
        return (writes, overlay)
    }

    @Test("A switch under Window count asks the run to travel")
    func switchTravels() throws {
        let (writes, overlay) = try secondPass(.count, from: 1, to: 2)
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

    /// A switch that also changes which items draw — a
    /// `hide_empty` drop — lands: pooled views would otherwise
    /// slide between different Spaces' slots.
    @Test("A changed item set lands")
    func changedItemsLand() throws {
        let writes = try secondPass(
            .count,
            from: 1,
            to: 2,
            dropEmpty: true
        ).writes
        #expect(!writes.isEmpty)
        #expect(!writes.contains { $0.travels })
    }

    /// A hidden bar forgets what it expanded, so it reappears
    /// rather than gliding from a stale Space.
    @Test("A hide forgets the expanded Space")
    func hideForgets() throws {
        let (_, overlay) = try secondPass(.count, from: 1, to: 2)
        overlay.hide()
        #expect(overlay.shownExpanded == nil)
        #expect(overlay.shownIdentities.isEmpty)
    }

    /// Hosted items ride their glass: the render moves none of
    /// them, and each glass and its backdrop are written to
    /// travel on a switch and to land on a steady pass.
    @Test("Box glass travels with its item")
    func boxGlassTravels() throws {
        try #require(Self.platformGlass)
        let (writes, overlay) = try secondPass(
            .count,
            from: 1,
            to: 2,
            boxedGlass: true
        )
        #expect(overlay.boxGlasses.count == 3)
        #expect(!writes.contains { $0.view is SpaceBarItemView })
        let glass = writes.filter { write in
            overlay.boxGlasses.contains { $0 === write.view }
        }
        let backdrops = writes.filter { $0.view is GlassBackdrop }
        #expect(glass.count == 3)
        #expect(backdrops.count == 3)
        #expect((glass + backdrops).allSatisfy { $0.travels })
        let steady = try secondPass(
            .count,
            from: 2,
            to: 2,
            boxedGlass: true
        ).writes
        #expect(steady.count == 6)
        #expect(!steady.contains { $0.travels })
    }
}
