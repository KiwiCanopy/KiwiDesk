import AppKit
import Testing

@testable import KiwiDeskCore

/// The section divider drags the Space Bar minimum (#1517, ruling
/// 15): only while the shelf is full, clamped between the hard
/// floor and the Space Bar's need and to the minimum's own range,
/// written through the settings-apply door; a double-click resets.
@Suite("Shelf divider drag")
@MainActor
struct ShelfDividerDragTests {
    init() { LiquidGlassGate.override = { false } }

    private func full(
        order: KiwiShelf.Order = .spacesFirst
    ) -> ShelfArrangement {
        var shelf = KiwiShelf()
        shelf.itemGap = 0
        shelf.order = order
        return ShelfArrangement.arrange(
            length: 1000,
            spaceNeed: 700,
            appNeed: 900,
            spaceFloor: 100,
            shelf: shelf
        )
    }

    @Test("Only a full shelf drags")
    func onlyFullDrags() throws {
        let divider = try #require(full().divider)
        #expect(divider.room == 1000)
        #expect(divider.bounds == 100...700)
        #expect(divider.spaceLength == 300)
        var shelf = KiwiShelf()
        shelf.itemGap = 0
        let fits = ShelfArrangement.arrange(
            length: 1000,
            spaceNeed: 300,
            appNeed: 600,
            spaceFloor: 100,
            shelf: shelf
        )
        #expect(fits.space != nil && fits.app != nil)
        #expect(fits.divider == nil)
    }

    @Test("A drag moves the minimum with the divider, either order")
    func dragFollowsTheDivider() throws {
        let divider = try #require(full().divider)
        // Spaces first: dragging toward the end grows the Spaces.
        #expect(divider.minimum(afterDragging: 100) == 40)
        #expect(divider.minimum(afterDragging: -50) == 25)
        let flipped = try #require(full(order: .appsFirst).divider)
        #expect(flipped.minimum(afterDragging: -100) == 40)
        #expect(flipped.minimum(afterDragging: 50) == 25)
    }

    @Test("A drag stops at the need, the floor and the range")
    func dragClamps() throws {
        let divider = try #require(full().divider)
        // Past the Space Bar's need (700 of 1000).
        #expect(divider.minimum(afterDragging: 900) == 70)
        // Below the hard floor (100) → then the range's 20 %.
        #expect(divider.minimum(afterDragging: -900) == 20)
        var narrow = divider
        narrow.bounds = 100...950
        #expect(narrow.minimum(afterDragging: 900) == 80)
    }

    private func mouse(
        _ type: NSEvent.EventType,
        x: CGFloat,
        clicks: Int = 1
    ) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type,
                location: CGPoint(x: x, y: 10),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: clicks,
                pressure: 1
            )
        )
    }

    @Test("The grip reports each step, then the release, then resets")
    func gripReports() throws {
        let handle = ShelfDividerHandle()
        handle.range = try #require(full().divider)
        var reports: [(CGFloat, Bool)] = []
        var resets = 0
        handle.onMinimum = { reports.append(($0, $1)) }
        handle.onReset = { resets += 1 }
        handle.mouseDown(with: try mouse(.leftMouseDown, x: 300))
        handle.mouseDragged(with: try mouse(.leftMouseDragged, x: 350))
        handle.mouseUp(with: try mouse(.leftMouseUp, x: 400))
        #expect(reports.map(\.0) == [35, 40])
        #expect(reports.map(\.1) == [false, true])
        handle.mouseDown(with: try mouse(.leftMouseDown, x: 400, clicks: 2))
        #expect(resets == 1)
        // A drag after a reset needs a fresh press.
        handle.mouseUp(with: try mouse(.leftMouseUp, x: 500))
        #expect(reports.count == 2)
    }

    @Test("The grip shows over the line only while the shelf is full")
    func gripOnlyWhileFull() throws {
        let overlay = ShelfOverlay()
        let strip = CGRect(x: 0, y: 0, width: 1000, height: 30)
        let sections = [
            ShelfOverlay.Section(
                view: NSView(),
                slot: CGRect(x: 0, y: 0, width: 300, height: 30),
                plate: .zero
            ),
            ShelfOverlay.Section(
                view: NSView(),
                slot: CGRect(x: 300, y: 0, width: 700, height: 30),
                plate: .zero
            ),
        ]
        overlay.show(strip: strip, shelf: KiwiShelf(), sections: sections)
        #expect(!overlay.divider.isHidden)
        #expect(overlay.handle.isHidden)
        overlay.show(
            strip: strip,
            shelf: KiwiShelf(),
            sections: sections,
            divider: try #require(full().divider)
        )
        #expect(!overlay.handle.isHidden)
        #expect(overlay.handle.frame.midX == overlay.divider.frame.midX)
        #expect(overlay.handle.frame.height == 30)
        overlay.hide()
    }

    /// The manager hands each shelf's grip its reports: a drag
    /// and a double-click both reach the one `onMinimum`.
    @Test("The manager wires the grip's drag and reset")
    func managerWiresTheGrip() throws {
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        let shelves = ShelfManager()
        var reports: [(CGFloat, Bool)] = []
        shelves.onMinimum = { reports.append(($0, $1)) }
        shelves.sync([
            .init(
                display: barTitleDisplay,
                strip: barTitleStrip,
                shelf: KiwiShelf(),
                space: (section, barTitleStrip),
                app: nil
            )
        ])
        let overlay = try #require(
            shelves.overlayForTesting(barTitleDisplay)
        )
        overlay.handle.onMinimum(42, false)
        overlay.handle.onReset()
        #expect(reports.map(\.0) == [42, KiwiShelf.resetMinimum])
        #expect(reports.map(\.1) == [false, true])
        overlay.hide()
    }

    /// The wiring: a release through the shelf manager reaches the
    /// live setting through `execute`; a step moves it too.
    @Test("The manager's report writes the live minimum")
    func managerWritesTheSetting() {
        let core = makeTestCore()
        core.shelves.onMinimum(45, false)
        #expect(core.tiler.settings.kiwishelf.minimum == 45)
        core.shelves.onMinimum(55, true)
        #expect(core.tiler.settings.kiwishelf.minimum == 55)
        core.shelves.onMinimum(KiwiShelf.resetMinimum, true)
        #expect(core.tiler.settings.kiwishelf.minimum == 30)
    }
}
