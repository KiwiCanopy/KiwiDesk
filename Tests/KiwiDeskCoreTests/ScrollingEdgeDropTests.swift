import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A mouse resize of a scrolling row's END column, dropped
/// through the real `handleDragEnd`.
///
/// The scrolling store is one slot length the whole row shares,
/// so no edge trades space with a neighbour and either edge of
/// any column resizes it. The outer-edge filter the split
/// layouts need dropped the last column's trailing edge (and the
/// first's leading one) and snapped it back — reachable under
/// the `center` anchor, which rests the last column mid-screen
/// (device, 2026-09-26). The bsp case is the control that the
/// filter still binds where a neighbour trade exists. The
/// display is pinned (#531).
@Suite("Scrolling end-column edge drops", .serialized)
@MainActor
struct ScrollingEdgeDropTests {
    private func makeCore(
        mode: String,
        vertical: Bool = false
    ) -> (KiwiCore, SpaceID) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-edge-drop-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.tiler.settings.scrolling.anchor = .center
        core.tiler.settings.scrolling.orientation =
            vertical ? .vertical : .horizontal
        for index in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        core.tiler.animation.isEnabled = false
        // Pinned away from every slot: no swap target, and no
        // other display for the relocate arm to find.
        core.drag.cursorLocation = {
            GeometryUtils.axPoint(CGPoint(x: -9000, y: -9000))
        }
        return (core, space)
    }

    /// The window at the far end of the row — the flat array's
    /// order, never a frame sort, since scrolled-out columns sit
    /// pinned at the edge — focused and retiled so its slot is
    /// the drawn one.
    private func endWindow(
        _ core: KiwiCore,
        _ space: SpaceID,
        last: Bool
    ) throws -> (WindowID, CGRect) {
        let row = try #require(core.state.workspaces[space]?.windows)
        let id = try #require(last ? row.last : row.first)
        core.state.workspaces.focus(id, in: space)
        core.retile()
        let slot = try #require(
            core.tiler.calculatedFrames(state: core.state)[id]
        )
        return (id, slot)
    }

    private func slotStore(
        _ core: KiwiCore,
        _ space: SpaceID
    ) -> ScrollSize? {
        core.state.workspaces[space]?.sessionRatios.slotSize
    }

    @Test("the last column's trailing edge resizes the row")
    func trailingEdgeOfLastColumn() throws {
        let (core, space) = makeCore(mode: "scrolling")
        let (id, slot) = try endWindow(
            core,
            space,
            last: true
        )
        var frame = slot
        frame.size.width -= 200
        #expect(slotStore(core, space) == nil)
        core.handleDragEnd(id, start: slot, frame: frame)
        #expect(slotStore(core, space) != nil)
    }

    @Test("the first column's leading edge resizes the row")
    func leadingEdgeOfFirstColumn() throws {
        let (core, space) = makeCore(mode: "scrolling")
        let (id, slot) = try endWindow(
            core,
            space,
            last: false
        )
        var frame = slot
        frame.origin.x += 200
        frame.size.width -= 200
        #expect(slotStore(core, space) == nil)
        core.handleDragEnd(id, start: slot, frame: frame)
        #expect(slotStore(core, space) != nil)
    }

    /// A vertical row's slot runs along the HEIGHT: the last
    /// row's bottom edge writes it, and a width-only drag —
    /// across the scroll axis — writes nothing.
    @Test("a vertical row resizes along its height")
    func verticalRowReadsTheHeight() throws {
        let (core, space) = makeCore(
            mode: "scrolling",
            vertical: true
        )
        let (id, slot) = try endWindow(
            core,
            space,
            last: true
        )
        var across = slot
        across.size.width -= 200
        core.handleDragEnd(id, start: slot, frame: across)
        #expect(slotStore(core, space) == nil)

        var along = slot
        along.size.height -= 200
        core.handleDragEnd(id, start: slot, frame: along)
        #expect(slotStore(core, space) != nil)
    }

    /// The pure half: `translate` reads the scroll axis's delta.
    @Test("translate reads the delta along the scroll axis")
    func translateFollowsTheAxis() {
        let slot = CGRect(x: 0, y: 0, width: 800, height: 600)
        let taller = CGRect(x: 0, y: 0, width: 800, height: 750)
        let bounds = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        func translate(vertical: Bool) -> ResizeAdjustment? {
            MouseResize.translate(
                mode: .scrolling,
                isMaster: false,
                stackSplitHorizontal: true,
                trackAxisVertical: false,
                scrollVertical: vertical,
                slot: slot,
                frame: taller,
                bounds: bounds
            )
        }
        #expect(translate(vertical: true) == .scrollSlot(150))
        #expect(translate(vertical: false) == nil)
    }

    /// Control: a split layout still refuses an outer edge,
    /// since there the resize trades with a neighbour.
    @Test("bsp still refuses an outer-edge drop")
    func bspOuterEdgeStillRefused() throws {
        let (core, space) = makeCore(mode: "bsp")
        let (id, slot) = try endWindow(
            core,
            space,
            last: true
        )
        var frame = slot
        frame.size.width -= 200
        let before = core.state.workspaces[space]?.sessionRatios
        core.handleDragEnd(id, start: slot, frame: frame)
        #expect(
            core.state.workspaces[space]?.sessionRatios == before
        )
    }
}
