import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The drop zone over an empty Space's placement (#3582): an empty
/// area of a split screen and an empty second screen show it at the
/// slot the drop then gives the window, through the real drag path;
/// a non-empty target keeps its swap zone, and an empty one the drop
/// would not tile into shows none. Needs a host screen to hang the
/// pinned frames on, so a screenless runner skips.
@Suite(
    "Drop zone over an empty placement",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct DragEmptyPlacementZoneTests {
    private static let whole = CGRect(x: 0, y: 0, width: 3440, height: 1440)

    private func addWindow(_ core: KiwiCore, _ raw: UInt32) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(raw), pid: 1, appName: "A\(raw)")
            )
        )
    }

    /// The Cocoa cursor at `offset` into the screen's own points.
    private func cursor(_ offset: CGPoint) -> CGPoint {
        let ax = GeometryUtils.flip(
            Self.whole,
            primaryHeight: GeometryUtils.primaryHeight
        )
        return GeometryUtils.axPoint(
            CGPoint(x: ax.minX + offset.x, y: ax.minY + offset.y)
        )
    }

    /// One wide screen split side by side: Space 1 (windows 1, 2)
    /// on the left, Space 2 on the right, empty.
    private func splitCore() -> KiwiCore? {
        guard let screen = ScreenList.all.first,
            let id = screen.kiwiDisplayID,
            let split = ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)
        else { return nil }
        let core = pinned(makeTestCore(), id: id)
        let display = Display(id: id, name: "Wide", frame: Self.whole)
        core.state.workspaces.setAreaSplits([display.fingerprint: split])
        core.state.workspaces.upsertDisplay(display)
        let areas = core.state.workspaces.placements(of: id).map(\.id)
        core.state.workspaces.assign(SpaceID("1"), to: areas[0])
        core.state.workspaces.assign(SpaceID("2"), to: areas[1])
        core.state.workspaces.activate(SpaceID("1"))
        addWindow(core, 1)
        addWindow(core, 2)
        core.dragCrossing.displayAt = { _ in id }
        return core
    }

    private func pinned(_ core: KiwiCore, id: DisplayID) -> KiwiCore {
        core.tiler.visibleBounds = { _ in Self.whole }
        core.tiler.screenFrameAX = { _ in Self.whole }
        core.tiler.displayFrames = { [(id: id, frame: Self.whole)] }
        core.tiler.settings.dragDropZone.enabled = true
        core.drag.isMousePressed = { true }
        return core
    }

    /// Drags window 1 a size-held step with the cursor at `point`.
    private func drag(_ core: KiwiCore, to point: CGPoint) throws -> CGRect {
        let home = try #require(core.shownSlots()[WindowID(1)])
        core.drag.cursorLocation = { point }
        let moved = home.offsetBy(dx: 40, dy: 0)
        core.handleDragMove(WindowID(1), start: home, frame: moved)
        return home
    }

    /// Drops it there and reads the slot it took.
    private func drop(_ core: KiwiCore, home: CGRect) -> CGRect? {
        core.handleDragEnd(
            WindowID(1),
            start: home,
            frame: home.offsetBy(dx: 40, dy: 0)
        )
        return core.tiler.calculatedFrames(state: core.state)[WindowID(1)]
    }

    @Test func emptyAreaShowsTheSlotTheDropGives() throws {
        let core = try #require(splitCore())
        let home = try drag(core, to: cursor(CGPoint(x: 3000, y: 700)))
        #expect(core.dragOverlay.isDropZoneVisible)
        let zone = try #require(core.dragOverlay.dropZoneFrame)
        #expect(zone.minX >= 1720)
        let landed = drop(core, home: home)
        #expect(core.state.workspaces.space(of: WindowID(1)) == "2")
        #expect(landed == zone)
    }

    @Test func emptySecondScreenShowsTheSlotTheDropGives() throws {
        guard let screen = ScreenList.all.first,
            let id = screen.kiwiDisplayID
        else { return }
        let other = DisplayID(900_611)
        let core = pinned(makeTestCore(), id: id)
        core.state.workspaces.assign(SpaceID("1"), to: id)
        core.state.workspaces.assign(SpaceID("2"), to: other)
        core.state.workspaces.activate(SpaceID("1"))
        addWindow(core, 1)
        addWindow(core, 2)
        core.dragCrossing.displayAt = { $0.x < 5000 ? id : other }
        let home = try drag(core, to: CGPoint(x: 6000, y: 300))
        #expect(core.dragOverlay.isDropZoneVisible)
        let zone = try #require(core.dragOverlay.dropZoneFrame)
        let landed = drop(core, home: home)
        #expect(core.state.workspaces.space(of: WindowID(1)) == "2")
        #expect(landed == zone)
    }

    /// The control: a window in the other area keeps the zone on
    /// its own slot, as a swap target.
    @Test func occupiedAreaKeepsTheSwapZone() throws {
        let core = try #require(splitCore())
        core.state.workspaces.activate(SpaceID("2"))
        addWindow(core, 3)
        core.state.workspaces.activate(SpaceID("1"))
        let slot = try #require(core.shownSlots()[WindowID(3)])
        _ = try drag(
            core,
            to: GeometryUtils.axPoint(CGPoint(x: slot.midX, y: slot.midY))
        )
        #expect(core.dragOverlay.isDropZoneVisible)
        #expect(core.dragOverlay.dropZoneFrame == slot)
    }

    /// An empty Space the drop does not tile into promises nothing.
    @Test func floatingEmptyAreaShowsNone() throws {
        let core = try #require(splitCore())
        core.state.workspaces.withSpace(SpaceID("2")) { $0.mode = .floating }
        _ = try drag(core, to: cursor(CGPoint(x: 3000, y: 700)))
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    /// A global sticky the move gate refuses snaps back, so the
    /// zone promises no move.
    @Test func refusedStickyShowsNone() throws {
        let core = try #require(splitCore())
        core.state.setSticky(WindowID(1), .global)
        _ = try drag(core, to: cursor(CGPoint(x: 3000, y: 700)))
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    /// A tiled global sticky follows the activation the drop makes,
    /// so the zone is the slot the window keeps beside it.
    @Test func globalStickyJoinsTheDrop() throws {
        let core = try #require(splitCore())
        core.state.setSticky(WindowID(2), .global)
        let home = try drag(core, to: cursor(CGPoint(x: 3000, y: 700)))
        let zone = try #require(core.dragOverlay.dropZoneFrame)
        let landed = drop(core, home: home)
        #expect(core.state.workspaces.space(of: WindowID(1)) == "2")
        #expect(landed == zone)
        let sticky = core.tiler.calculatedFrames(state: core.state)[
            WindowID(2)
        ]
        #expect(sticky.map { $0.minX >= 1720 } == true)
    }

    /// A screen on a full-screen Space shows no zone: the Space a
    /// drop files into is not on screen.
    @Test func fullScreenScreenShowsNone() throws {
        let core = try #require(splitCore())
        core.desktopMemory.readDisplayUUID = { _ in "FS" }
        core.desktopMemory.shownUserSpaces = ["FS": false]
        _ = try drag(core, to: cursor(CGPoint(x: 3000, y: 700)))
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    /// The live crossing (#504) files the window first; the zone
    /// stays on the slot it took.
    @Test(arguments: [false, true])
    func crossingKeepsTheZone(withSticky: Bool) throws {
        guard let screen = ScreenList.all.first,
            let id = screen.kiwiDisplayID
        else { return }
        let other = DisplayID(900_612)
        let core = pinned(makeTestCore(), id: id)
        core.state.workspaces.assign(SpaceID("1"), to: id)
        core.state.workspaces.assign(SpaceID("2"), to: other)
        core.state.workspaces.activate(SpaceID("1"))
        addWindow(core, 1)
        addWindow(core, 2)
        core.dragCrossing.displayAt = { $0.x < 5000 ? id : other }
        // A global sticky tile follows the crossing's activation.
        if withSticky { core.state.setSticky(WindowID(2), .global) }
        let point = CGPoint(x: 6000, y: 300)
        let home = try drag(core, to: point)
        let zone = try #require(core.dragOverlay.dropZoneFrame)
        core.dragCrossing.onCross(
            WindowID(1),
            core.state.workspaces.placementOrWhole(of: other)
        )
        #expect(core.state.workspaces.space(of: WindowID(1)) == "2")
        core.handleDragMove(
            WindowID(1),
            start: home,
            frame: home.offsetBy(dx: 80, dy: 0)
        )
        #expect(core.dragOverlay.dropZoneFrame == zone)
    }

    /// Every layout the empty Space can wear lands the window on
    /// the zone, so a new layout is held without a case of its own.
    @Test func everyLayoutLandsOnTheZone() throws {
        for mode in LayoutMode.allCases where mode != .floating {
            let core = try #require(splitCore())
            core.state.workspaces.withSpace(SpaceID("2")) {
                $0.mode = mode
            }
            let home = try drag(
                core,
                to: cursor(CGPoint(x: 3000, y: 700))
            )
            let zone = core.dragOverlay.dropZoneFrame
            #expect(zone != nil, "\(mode)")
            #expect(drop(core, home: home) == zone, "\(mode)")
        }
    }

    /// An occupied area's gap is no empty placement: the zone stays
    /// off where no slot is under the pointer.
    @Test func occupiedAreaGapShowsNone() throws {
        let core = try #require(splitCore())
        core.execute("set_gap_global", args: [.number(40)])
        core.state.workspaces.activate(SpaceID("2"))
        addWindow(core, 3)
        core.state.workspaces.activate(SpaceID("1"))
        let slot = try #require(core.shownSlots()[WindowID(3)])
        let gap = GeometryUtils.axPoint(
            CGPoint(x: slot.minX - 10, y: slot.midY)
        )
        #expect(slot.minX - 10 > 1720)
        _ = try drag(core, to: gap)
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    /// After a crossing, a pointer back in a gap of the screen it
    /// left drops the window there, so the zone leaves the slot the
    /// crossing gave it.
    @Test func crossingBackShowsNone() throws {
        guard let screen = ScreenList.all.first,
            let id = screen.kiwiDisplayID
        else { return }
        let other = DisplayID(900_613)
        let core = pinned(makeTestCore(), id: id)
        core.execute("set_gap_global", args: [.number(40)])
        core.state.workspaces.assign(SpaceID("1"), to: id)
        core.state.workspaces.assign(SpaceID("2"), to: other)
        core.state.workspaces.activate(SpaceID("1"))
        addWindow(core, 1)
        addWindow(core, 2)
        core.dragCrossing.displayAt = { $0.x < 5000 ? id : other }
        let home = try drag(core, to: CGPoint(x: 6000, y: 300))
        core.dragCrossing.onCross(
            WindowID(1),
            core.state.workspaces.placementOrWhole(of: other)
        )
        let gap = GeometryUtils.axPoint(CGPoint(x: 10, y: 700))
        core.drag.cursorLocation = { gap }
        core.handleDragMove(
            WindowID(1),
            start: home,
            frame: home.offsetBy(dx: 80, dy: 0)
        )
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    /// A drop zone turned off stays off beside a shown ghost.
    @Test func zoneOffShowsNone() throws {
        let core = try #require(splitCore())
        core.tiler.settings.dragGhost.enabled = true
        core.tiler.settings.dragDropZone.enabled = false
        _ = try drag(core, to: cursor(CGPoint(x: 3000, y: 700)))
        #expect(core.dragOverlay.isGhostVisible)
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    /// The probe is a what-if read: the monocle hold it lays out
    /// for an empty Monocle Space is not left in the live engine.
    @Test func probeLeavesTheMonocleHold() throws {
        let core = try #require(splitCore())
        core.state.workspaces.withSpace(SpaceID("2")) {
            $0.mode = .monocle
        }
        let before = core.tiler.monocleShownMembers
        _ = try drag(core, to: cursor(CGPoint(x: 3000, y: 700)))
        #expect(core.dragOverlay.isDropZoneVisible)
        #expect(core.tiler.monocleShownMembers == before)
    }
}
