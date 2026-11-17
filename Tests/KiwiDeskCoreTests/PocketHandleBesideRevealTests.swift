import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket's handle beside a hiding Space Bar on its own edge
/// (#3432): the handle rests in its slot band, and the bar's reveal
/// and retract leave the pocket's place and its approach alone, so
/// an approach after a retract rises it. The bar is driven through
/// the real revealer, its changes reaching `updateBars()` as
/// production's `onChange` does.
@Suite(
    "Pocket handle beside a revealed bar (#3432)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketHandleBesideRevealTests {
    typealias Rig = PocketApproachTests.Rig

    /// The approach rig with the Space Bar at `visibility` on the
    /// pocket's edge, every revealer change running the bar pass.
    func rig(
        _ visibility: ShelfVisibility = .auto
    ) throws -> (Rig, ShelfRevealer.Key) {
        let rig = try PocketApproachTests().rig()
        let core = rig.core
        core.execute("space_bar.set_edge", args: [.string("left")])
        core.execute("kiwishelf.set_pocket_edge", args: [.string("left")])
        core.tiler.settings.spaceBarStyle.visibility = visibility
        core.shelves.reveal.onChange = { [weak core] in core?.updateBars() }
        core.updateBars()
        let bar = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: rig.display, edge: .left),
            bar: .space
        )
        return (rig, bar)
    }

    @Test("a retracted bar leaves the pocket's approach filed")
    func retractKeepsTheApproach() throws {
        let (rig, bar) = try rig()
        defer { BarMotion.reducedOverride = nil }
        let core = rig.core
        #expect(core.pocketPlace(on: rig.display) == .handle)
        #expect(rig.target != nil)
        #expect(core.toggleBarReveal(bar))
        #expect(core.shelves.reveal.reveal(of: bar).isShown)
        #expect(core.toggleBarReveal(bar))
        #expect(!core.shelves.reveal.reveal(of: bar).isShown)
        #expect(core.pocketPlace(on: rig.display) == .handle)
        let target = try #require(rig.target)
        // The approach rises it as before the reveal.
        let tab = try PocketApproachTests().onTab(target)
        rig.pointer.point = tab
        core.shelves.reveal.moved(to: tab)
        #expect(core.shelves.reveal.fills[rig.key] != nil)
    }

    @Test("the handle rests in its slot band, and a reveal moves it not")
    func revealLeavesTheHandle() throws {
        let (rig, bar) = try rig()
        defer { BarMotion.reducedOverride = nil }
        let core = rig.core
        let band = try #require(core.pocketPlate.markBands[rig.display])
        let rest = try #require(rig.spec)
        // AX, along the left edge: in its slot, not at Position.
        let handle = try #require(
            core.pocketHandleFrame(on: rig.display, risen: false)
        )
        let screen = try #require(NSScreen.main)
        let position = KiwiCore.pocketHandleFrame(
            visible: GeometryUtils.axVisibleFrame(of: screen),
            edge: .left,
            position: core.shelf(on: rig.display).pocketPosition,
            depth: handle.width
        )
        #expect(band.contains(handle.midY))
        #expect(abs(handle.midY - position.midY) > 1)
        #expect(core.toggleBarReveal(bar))
        #expect(core.shelves.reveal.reveal(of: bar).isShown)
        // The bar comes in alone: no section, the handle standing.
        #expect(core.pocketPlate.slots[rig.display] == nil)
        #expect(core.pocketPlace(on: rig.display) == .handle)
        #expect(rig.target != nil)
        #expect(rig.spec?.frame == rest.frame)
        // The bar is held over its own run, never the pocket's band.
        let held = try #require(core.shelves.reveal.targets[bar]?.section)
        #expect(!held.intersects(try #require(rig.target?.handle)))
    }

    @Test("the bar's approach stops short of the pocket's tab")
    func approachesApart() throws {
        let (rig, bar) = try rig()
        defer { BarMotion.reducedOverride = nil }
        let core = rig.core
        // The run ends against the pocket's slot, at the edge's end.
        core.tiler.settings.kiwishelf.alignment = .end
        core.updateBars()
        let barApproach = try #require(
            core.shelves.reveal.targets[bar]?.approach
        )
        let tab = try #require(rig.target?.approach)
        #expect(!barApproach.intersects(tab))
    }

    @Test("a pass files the approach from its own slots")
    func filesThePassSlot() throws {
        let (rig, _) = try rig(.always)
        defer { BarMotion.reducedOverride = nil }
        let core = rig.core
        // Control: beside an Always bar the pocket is a section.
        #expect(core.pocketPlate.slots[rig.display] != nil)
        #expect(rig.target == nil)
        // One pass after the bar turns Auto: no slot, and the
        // approach is filed in that same pass.
        core.tiler.settings.spaceBarStyle.visibility = .auto
        core.updateBars()
        #expect(core.pocketPlate.slots[rig.display] == nil)
        #expect(rig.target != nil)
    }

    @Test("a Hidden bar's reveal leaves the pocket where it rests")
    func hiddenRevealLeavesThePocket() throws {
        let (rig, bar) = try rig(.hidden)
        defer { BarMotion.reducedOverride = nil }
        let core = rig.core
        // No bar rests here, so the pocket keeps no slot or band.
        #expect(core.pocketPlate.markBands[rig.display] == nil)
        let rest = try #require(rig.spec)
        #expect(core.toggleBarReveal(bar))
        #expect(core.shelves.reveal.reveal(of: bar).isShown)
        #expect(core.pocketPlate.slots[rig.display] == nil)
        #expect(core.pocketPlace(on: rig.display) == .handle)
        #expect(rig.spec?.frame == rest.frame)
        #expect(core.toggleBarReveal(bar))
        #expect(rig.target != nil)
    }
}
