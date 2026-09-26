import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A mouse resize of a scrolling row's END column, dropped
/// through the real `handleDragEnd`: one slot length serves the
/// row, so no edge trades with a neighbour and either edge of
/// any column resizes it (`MouseResize.tradesWithNeighbors`).
/// The bsp case is the control that the outer-edge filter still
/// binds where a neighbour trade exists. The display is pinned
/// (#531).
///
/// Requires a screen, as a trait: `handleResizeEnd` writes
/// nothing when no screen resolves, so headless the two cases
/// asserting "nothing written" would pass without testing
/// anything. A SKIP says that; a green would not.
@Suite(
    "Scrolling end-column edge drops",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
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
        // Per Space, never the global: the drop resolves the
        // axis through that Space's own override.
        if vertical {
            var override = ScrollingOverride()
            override.orientation = .vertical
            core.tiler.settings.scrolling.override[space] = override
        }
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

    /// The drawn extent after the drop, along the row's axis.
    private func drawnExtent(
        _ core: KiwiCore,
        _ id: WindowID,
        vertical: Bool = false
    ) throws -> CGFloat {
        core.retile()
        let frame = try #require(
            core.tiler.calculatedFrames(state: core.state)[id]
        )
        return vertical ? frame.height : frame.width
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
        // The row is drawn at the dropped width, not back at
        // the start (or pushed the other way).
        #expect(abs(try drawnExtent(core, id) - frame.width) <= 2)
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
    /// row's bottom edge writes it...
    @Test("a vertical row resizes along its height")
    func verticalRowReadsTheHeight() throws {
        let (core, space) = makeCore(
            mode: "scrolling",
            vertical: true
        )
        let (id, slot) = try endWindow(core, space, last: true)
        var along = slot
        along.size.height -= 200
        core.handleDragEnd(id, start: slot, frame: along)
        #expect(slotStore(core, space) != nil)
        #expect(
            abs(
                try drawnExtent(core, id, vertical: true)
                    - along.height
            ) <= 2
        )
    }

    /// ...and a width-only drag, across the scroll axis, writes
    /// nothing. Its own core, so neither half rides the other.
    @Test("a vertical row ignores a width drag")
    func verticalRowIgnoresTheWidth() throws {
        let (core, space) = makeCore(
            mode: "scrolling",
            vertical: true
        )
        let (id, slot) = try endWindow(core, space, last: true)
        var across = slot
        across.size.width -= 200
        core.handleDragEnd(id, start: slot, frame: across)
        #expect(slotStore(core, space) == nil)
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
