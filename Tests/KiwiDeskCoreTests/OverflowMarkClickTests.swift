import AppKit
import Testing

@testable import KiwiDeskCore

/// The overflow mark's list through a real core (#2563 ▸ Ruling):
/// hover opens nothing, a click grows and holds the list, and it
/// closes on its own triggers. The peek reads its anchor off a
/// window on screen, so the core orders its marks in; the run
/// resolves the Space's screen, hence `.enabled(if:)`.
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
    final class Rig {
        let core: KiwiCore
        let space: SpaceID
        var clock: TimeInterval = 100
        /// The morph's landings, run by `land()` rather than a timer.
        var landings: [@MainActor () -> Void] = []

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
            peek.panel.land = { [unowned self] _, body in
                self.landings.append(body)
            }
        }

        /// Lands every morph in flight.
        func land() {
            let due = landings
            landings = []
            due.forEach { $0() }
        }

        /// Whether a morph's motion is on the panel's stage.
        var stageMorphs: Bool {
            peek.panel.stage.layer?.animationKeys()?
                .contains(BarMotion.morphKey) == true
        }

        var peek: BarPeek { core.shelves.peek }

        var overlay: OverflowMarkOverlay {
            get throws {
                try #require(core.overflowMarks.overlays.values.first)
            }
        }

        /// A press on the mark, released at `release` in the mark's
        /// window — its middle unless a drag moved it off.
        func click(releaseOff: Bool = false) throws {
            let view = try overlay.view
            let mid = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            func mouse(_ type: NSEvent.EventType, _ at: CGPoint) throws
                -> NSEvent
            {
                try #require(
                    NSEvent.mouseEvent(
                        with: type,
                        location: at,
                        modifierFlags: [],
                        timestamp: 0,
                        windowNumber: 0,
                        context: nil,
                        eventNumber: 0,
                        clickCount: 1,
                        pressure: 1
                    )
                )
            }
            view.mouseDown(with: try mouse(.leftMouseDown, mid))
            let off = CGPoint(x: mid.x + 200, y: mid.y + 200)
            view.mouseUp(with: try mouse(.leftMouseUp, releaseOff ? off : mid))
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

    /// A press is often a window drag begun just past the mark: the
    /// list opens on the release inside it, and a drag off cancels.
    @Test("The list opens on the release; a drag off opens nothing")
    func opensOnRelease() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click(releaseOff: true)
        #expect(rig.peek.shown == nil)
        try rig.click()
        #expect(rig.peek.shown != nil)
    }

    @Test("A click grows the list and hides the pill under it")
    func clickGrowsTheList() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        let shown = try #require(rig.peek.shown)
        #expect(shown.source.opensOnClick)
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
        #expect(rig.peek.shown?.source.opensOnClick == true)
        rig.peek.pointer(in: item, on: nil, source: nil, edge: .bottom)
        #expect(rig.peek.shown?.source.opensOnClick == true)
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
        // Past the interval a second press still keeps it: the click
        // count is a gate of its own.
        panel.headerPressed(2)
        #expect(rig.peek.shown != nil)
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
    /// ordered out before its list closes, so the list fades and no
    /// shrink plays on the stage. Reads the clip, so it asks for
    /// the growth Reduce Motion would replace.
    @Test(
        "A list whose mark is gone fades rather than shrinking",
        .enabled(
            if: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
    )
    func goneMarkFades() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        rig.land()
        try #require(!rig.stageMorphs)
        let view = try rig.overlay.view
        rig.core.overflowMarks.sync([])
        #expect(rig.peek.shown == nil)
        #expect(view.window?.isVisible != true)
        #expect(!rig.stageMorphs)
        #expect(rig.peek.panel.panel?.ignoresMouseEvents == true)
    }

    /// The pill comes back only as the shrink lands, taking the
    /// pointer again; the list is then gone.
    @Test("The pill returns when the close lands")
    func pillReturnsAtTheLanding() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        rig.land()
        let markPanel = try #require(try rig.overlay.panel)
        #expect(markPanel.ignoresMouseEvents)
        #expect(rig.peek.panel.morphKey(53))
        #expect(markPanel.ignoresMouseEvents)
        #expect(rig.peek.panel.morph != nil)
        rig.land()
        #expect(!markPanel.ignoresMouseEvents)
        #expect(markPanel.alphaValue == 1)
        #expect(rig.peek.panel.morph == nil)
        #expect(rig.peek.panel.panel?.isVisible != true)
    }
}
