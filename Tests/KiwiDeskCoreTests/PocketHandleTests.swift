import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket's handle on an edge no bar shows (#2678, 2026-10-29
/// ruling): a fixed mark at Position, out of which the pocket rises
/// on hover and during a drag, to the bar's size kept in 20...32 pt.
@Suite(
    "Pocket handle",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketHandleTests {
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-handle-\(UUID().uuidString)")
        )
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        core.execute("pocket.set_capacity", args: [.string("several")])
        return core
    }

    private func spec(_ core: KiwiCore) -> PocketPlateOverlay.Spec? {
        core.updatePocketPlate(slots: [:])
        return core.pocketPlate.specs.values.first
    }

    @Test("the risen size is the bar's, kept within 20...32 pt")
    func riseSide() {
        #expect(KiwiCore.pocketRiseSide(thickness: 40) == 32)
        #expect(KiwiCore.pocketRiseSide(thickness: 60) == 32)
        #expect(KiwiCore.pocketRiseSide(thickness: 20) == 20)
        let cell = SpaceBarItemView.cell(contentDepth: 30)
        #expect((20...32).contains(cell))
        #expect(KiwiCore.pocketRiseSide(thickness: 30) == cell)
    }

    @Test("the band stands at Position, kept whole on the edge")
    func bandPlacement() {
        let visible = CGRect(x: 0, y: 25, width: 1000, height: 800)
        let mid = KiwiCore.pocketHandleFrame(
            visible: visible,
            edge: .bottom,
            position: 50,
            depth: 16
        )
        #expect(mid.midX == 500)
        #expect(mid.maxY == visible.maxY)
        #expect(mid.height == 16)
        let end = KiwiCore.pocketHandleFrame(
            visible: visible,
            edge: .bottom,
            position: 100,
            depth: 16
        )
        #expect(end.maxX == visible.maxX)
        let side = KiwiCore.pocketHandleFrame(
            visible: visible,
            edge: .right,
            position: 0,
            depth: 16
        )
        #expect(side.minY == visible.minY)
        #expect(side.maxX == visible.maxX)
    }

    @Test("an edge no bar shows takes the handle at rest")
    func handleAtRest() throws {
        let core = try makeCore()
        core.tiler.settings.kiwishelf.outerMargin = 8
        let shown = try #require(spec(core))
        #expect(shown.handle == core.tiler.settings.kiwishelf.pocketEdge)
        #expect(!shown.risen)
        let depth =
            shown.handle?.isHorizontal == false
            ? shown.frame.width : shown.frame.height
        // It reaches the edge across the outer margin and draws
        // past it, as the bars' handles sit.
        #expect(depth == PocketHandleView.restDepth + 8)
    }

    @Test("a hover raises the pocket out of its handle, and leaving sinks it")
    func hoverRises() throws {
        let core = try makeCore()
        let shown = try #require(spec(core))
        core.pocketHovered(shown.display, true)
        let risen = try #require(core.pocketPlate.specs[shown.display])
        #expect(risen.risen)
        #expect(risen.frame.height > shown.frame.height)
        core.pocketHovered(shown.display, false)
        #expect(core.pocketPlate.specs[shown.display]?.risen == false)
    }

    @Test("a window drag raises the pocket on every display")
    func dragRises() throws {
        let core = try makeCore()
        core.tiler.settings.kiwishelf.outerMargin = 8
        core.pocketPlate.dragging = WindowID(7)
        let shown = try #require(spec(core))
        #expect(shown.risen)
        // Risen, it still stands one outer margin in.
        let shelf = core.tiler.settings.kiwishelf
        let depth =
            shown.handle?.isHorizontal == false
            ? shown.frame.width : shown.frame.height
        #expect(
            depth
                == 8 + PocketHandleView.tabDepth + PocketPlateView.lift
                + KiwiCore.pocketRiseSide(thickness: shelf.thickness)
        )
        // Above the drag's ghost, which shares the bars' level.
        #expect(shown.aboveDrag)
        let panel = try #require(
            core.pocketPlate.panelForTesting(on: shown.display)
        )
        #expect(panel.level == BarPanel.aboveLevel)
        core.pocketPlate.dragging = nil
        _ = spec(core)
        #expect(panel.level == BarPanel.level)
    }

    @Test("a bar edge's slot keeps the section, never the handle")
    func slotIsNoHandle() throws {
        let core = try makeCore()
        let display = try #require(spec(core)?.display)
        core.updatePocketPlate(
            slots: [display: CGRect(x: 10, y: 10, width: 40, height: 40)]
        )
        // Hovered and dragged over, a section still never rises.
        core.pocketPlate.hovered = [display]
        core.pocketPlate.dragging = WindowID(1)
        core.updatePocketPlate()
        let shown = try #require(core.pocketPlate.specs[display])
        #expect(shown.handle == nil)
        #expect(!shown.risen)
    }

    @Test("a section's hover outlasts the handle it replaced")
    func sectionKeepsItsHover() throws {
        let core = try makeCore()
        let display = try #require(spec(core)?.display)
        // The edge gains a bar: the handle gives way to a section.
        let slot = CGRect(x: 1000, y: 860, width: 40, height: 40)
        core.updatePocketPlate(slots: [display: slot])
        core.pocketHovered(display, true)
        // A later pass keeps it lit, so the empty pocket stays full.
        core.updatePocketPlate(slots: [display: slot])
        #expect(core.pocketPlate.hovered.contains(display))
        #expect(core.pocketPlate.specs[display]?.faded == false)
    }
}
