import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The overflow mark's list through a real core (#2563 ▸ Ruling):
/// hover lights the mark and opens nothing, a click grows the list
/// and holds it, and it closes on its own triggers, never on the
/// pointer leaving. The peek reads its anchor's frame only off a
/// window on screen, so this core orders its mark panels in and
/// takes them and the peek out again. `.enabled(if:)` because the
/// run resolves the Space's screen.
@Suite(
    "Overflow mark click (#2563)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct OverflowMarkClickTests {
    /// A core with six windows in one stack Space, focus on window
    /// 2, so the run's tail hides 4…6 behind window 3; its marks
    /// order in and its peek's clock reads `clock`.
    @MainActor
    private final class Rig {
        let core: KiwiCore
        let space: SpaceID
        var clock: TimeInterval = 100

        init() {
            core = makeTestCore(
                configDirectory:
                    testTemporaryDirectory
                    .appendingPathComponent(
                        "kiwi-overflow-click-\(UUID().uuidString)"
                    )
            )
            // Pinned (tests.md, #531): the stack must overflow.
            core.tiler.visibleBounds = { _ in
                CGRect(x: 0, y: 25, width: 1440, height: 800)
            }
            core.overflowMarks.ordersPanels = true
            for id in 1...6 {
                core.state.apply(
                    .windowCreated(
                        ManagedWindow(
                            id: WindowID(UInt32(id)),
                            pid: pid_t(900_000 + id),
                            appName: "App"
                        )
                    )
                )
            }
            space = core.state.workspaces.space(of: WindowID(1))!
            _ = core.execute(
                "set_mode",
                args: [.string(space.raw), .string("stack")]
            )
            _ = core.execute("set_min_window_size", args: [.number(300)])
            core.state.workspaces.focus(WindowID(2), in: space)
            core.retile(animated: false)
            peek.visibleArea = { _ in
                CGRect(x: 0, y: 0, width: 1440, height: 900)
            }
            peek.now = { [unowned self] in self.clock }
        }

        var peek: BarPeek { core.shelves.peek }

        var overlay: OverflowMarkOverlay {
            get throws {
                try #require(core.overflowMarks.overlays.values.first)
            }
        }

        func click() throws {
            let event = try #require(
                NSEvent.mouseEvent(
                    with: .leftMouseDown,
                    location: .zero,
                    modifierFlags: [],
                    timestamp: 0,
                    windowNumber: 0,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: 1
                )
            )
            try overlay.view.mouseDown(with: event)
        }

        func close() {
            peek.dismiss()
            peek.panel.panel?.orderOut(nil)
            core.overflowMarks.clear()
        }
    }

    private static func crossing(_ type: NSEvent.EventType) throws -> NSEvent {
        try #require(
            NSEvent.enterExitEvent(
                with: type,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                trackingNumber: 0,
                userData: nil
            )
        )
    }

    @Test("Hover lights the mark and opens nothing")
    func hoverOpensNothing() throws {
        let rig = Rig()
        defer { rig.close() }
        let view = try rig.overlay.view
        view.mouseEntered(with: try Self.crossing(.mouseEntered))
        #expect(view.hovered)
        #expect(!view.highlight.isHidden)
        #expect(rig.peek.shown == nil)
        #expect(rig.peek.pending == nil)
        view.mouseExited(with: try Self.crossing(.mouseExited))
        #expect(!view.hovered)
        #expect(view.highlight.isHidden)
    }

    @Test("A click grows the list and hides the pill under it")
    func clickGrowsTheList() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        let shown = try #require(rig.peek.shown)
        #expect(shown.source.morphsFromAnchor)
        #expect(rig.peek.panel.morph != nil)
        #expect(!rig.peek.panel.header.isHidden)
        #expect(try rig.overlay.panel?.ignoresMouseEvents == true)
        #expect(
            rig.peek.panel.header.listInk.stringValue
                == (try rig.overlay.view.morphText)
        )
    }

    /// A held list is no hover's: another bar item reporting the
    /// pointer neither swaps it nor closes it.
    @Test("Another item's hover leaves a held list")
    func otherHoverLeavesIt() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        let item = NSView()
        rig.peek.pointer(
            in: item,
            on: item,
            source: .glyph([WindowID(1), WindowID(2)]),
            edge: .bottom
        )
        #expect(rig.peek.shown?.source.morphsFromAnchor == true)
        rig.peek.pointer(in: item, on: nil, source: nil, edge: .bottom)
        #expect(rig.peek.shown?.source.morphsFromAnchor == true)
    }

    @Test("Escape closes the list; the arrows walk its rows")
    func keysOnTheList() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        let panel = rig.peek.panel
        #expect(panel.panel?.canBecomeKey == true)
        #expect(panel.morphKey(125))
        #expect(panel.body.hovered == 0)
        #expect(panel.morphKey(125))
        #expect(panel.body.hovered == 1)
        #expect(panel.morphKey(126))
        #expect(panel.body.hovered == 0)
        #expect(!panel.morphKey(0))
        #expect(panel.morphKey(53))
        #expect(rig.peek.shown == nil)
    }

    /// The second press of the double-click that opened it lands on
    /// the header and keeps the list (#2063).
    @Test("The header closes it, save a double-click's second press")
    func headerCloses() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        let panel = rig.peek.panel
        panel.headerPressed(2)
        #expect(rig.peek.shown != nil)
        rig.clock += 0.05
        panel.headerPressed(1)
        #expect(rig.peek.shown != nil)
        rig.clock += 5
        panel.headerPressed(1)
        #expect(rig.peek.shown == nil)
    }

    @Test("The anchor window moving closes the list")
    func anchorMoveCloses() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        let overlay = try rig.overlay
        let frame = try #require(overlay.lastFrame)
        rig.core.overflowMarks.reposition(
            overlay.mark.anchor,
            windowFrame: frame.offsetBy(dx: 0, dy: 40)
        )
        #expect(rig.peek.shown == nil)
    }

    @Test("A Desktop switch closes the list")
    func desktopSwitchCloses() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        rig.core.handle(.desktopChanged)
        #expect(rig.peek.shown == nil)
    }

    @Test("KiwiVision turning on closes the list")
    func visionCloses() throws {
        let rig = Rig()
        defer {
            rig.core.setVision(.off)
            rig.close()
        }
        try rig.click()
        rig.core.setVision(.plain)
        #expect(rig.peek.shown == nil)
    }

    /// A mark that is gone leaves nothing to shrink into: it is
    /// ordered out before its list closes, so the list fades.
    @Test("A list whose mark is gone closes with the mark hidden")
    func goneMarkFades() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        let view = try rig.overlay.view
        rig.core.overflowMarks.sync([])
        #expect(rig.peek.shown == nil)
        #expect(view.window?.isVisible != true)
        #expect(rig.peek.panel.panel?.ignoresMouseEvents == true)
    }
}
