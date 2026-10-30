import AppKit
import Testing

@testable import KiwiDeskCore

/// The pocket's strip reaches the live layout (#2784): the capacity
/// enters the bounds through `TilingEngine.pocketAtRest`, a capacity
/// change that moves a strip owes a pass and one that moves none only
/// a repaint, and the whole mark draws exactly where
/// `TilingSettings.pocketRest` answers `.mark`.
@Suite("Pocket reservation wiring (#2784)", .serialized)
@MainActor
struct PocketReservationCoreTests {
    /// A core on the first screen, its Space Bar on top at `space`,
    /// the pocket on `pocket`; nil on a host with no screen.
    private func makeCore(
        space visibility: ShelfVisibility,
        pocket: AppBarEdge
    ) -> (KiwiCore, NSScreen, Space)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.resolveSpaceDisplays(mainID: display.id)
        core.tiler.settings.spaceBarStyle.setEdge(.top)
        core.tiler.settings.spaceBarStyle.visibility = visibility
        core.tiler.settings.kiwishelf.pocketEdge = pocket
        guard
            let id = core.state.workspaces.currentSpace(on: display.id),
            let space = core.state.workspaces[id]
        else { return nil }
        core.state.workspaces.setMode(id, .bsp)
        return (core, screen, space)
    }

    private func passes(_ meter: WorkMeter) -> Int {
        let counts = meter.snapshot(reset: false).counts
        return counts.retiles + counts.passesHeld
    }

    @Test(
        "Several reserves the handle's strip and owes a pass",
        .enabled(if: NSScreen.main != nil)
    )
    func capacityMovesTheBounds() throws {
        let (core, screen, space) = try #require(
            makeCore(space: .hidden, pocket: .top)
        )
        let before = core.tiler.layoutBounds(on: screen, for: space)
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        core.setAppWide(persisting: false) { $0.pocketCapacity = .several }
        let after = core.tiler.layoutBounds(on: screen, for: space)
        #expect(
            before.height - after.height
                == core.tiler.settings.kiwishelf.hiddenReservation
        )
        #expect(passes(meter) == 1)
    }

    @Test(
        "a capacity change that moves no strip repaints, no pass",
        .enabled(if: NSScreen.main != nil)
    )
    func sectionMovesNothing() throws {
        let (core, screen, space) = try #require(
            makeCore(space: .always, pocket: .top)
        )
        let before = core.tiler.layoutBounds(on: screen, for: space)
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        core.setAppWide(persisting: false) { $0.pocketCapacity = .several }
        #expect(core.tiler.layoutBounds(on: screen, for: space) == before)
        #expect(passes(meter) == 0)
    }

    @Test(
        "the whole mark draws where the rest answers mark, alone",
        .enabled(if: NSScreen.main != nil)
    )
    func wholeFollowsTheRest() throws {
        for (visibility, whole) in [
            (ShelfVisibility.always, true), (.auto, false),
        ] {
            let (core, _, _) = try #require(
                makeCore(space: visibility, pocket: .bottom)
            )
            core.setAppWide(persisting: false) {
                $0.pocketCapacity = .several
            }
            let spec = try #require(core.pocketPlateSpecs().first)
            #expect(spec.whole == whole, "\(visibility)")
            #expect(spec.risen == false)
        }
    }
}
