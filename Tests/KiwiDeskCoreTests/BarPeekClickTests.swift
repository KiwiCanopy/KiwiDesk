import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A click on a rendered list glyph (#1946, owner ruling amendment
/// 2): it shows the peek at once and presents no menu, VoiceOver's
/// press presents the native menu once, a press elsewhere on the
/// shelf closes it, and a peek row picks through Core's one bar-row
/// pick — the window menu's — doing what the row's glyph does: a
/// window on an unshown Desktop takes the chip's plain switch.
@Suite("Bar hover peek clicks", .serialized)
@MainActor
struct BarPeekClickTests {
    private let display = barTitleDisplay
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    init() {
        LiquidGlassGate.override = { false }
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    /// Space 1 active on Notes (1); Space 2 holds Web 4 and 5, one
    /// glyph of two windows.
    private func seededCore() -> KiwiCore {
        let core = makeBarCore()
        // The peek stands on the shelf's panel (#1894).
        core.shelves.drawsPanels = true
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(two)
        core.state.apply(
            .windowCreated(titledWindow(4, app: "Web", title: "Doc"))
        )
        core.state.apply(
            .windowCreated(titledWindow(5, app: "Web", title: "Mail"))
        )
        core.state.workspaces.activate(one)
        core.state.apply(
            .windowCreated(titledWindow(1, app: "Notes", title: "Memo"))
        )
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    /// Renders the bars and returns Space 2's Web target.
    private func webTarget(_ core: KiwiCore) throws -> SpaceBarGlyphTarget {
        var style = SpaceBarLook()
        style.liquidGlass = false
        let items = core.spaceBarItems(display: display, style: style)
        core.shelves.holdingRelayout {
            core.spaceBars.sync([
                SpaceBarManager.Bar(
                    display: display,
                    items: items,
                    strip: barTitleStrip,
                    style: style,
                    stateMarkColors: StateMarkColors(
                        sticky: "#ffffff",
                        floating: "#ffffff"
                    )
                )
            ])
        }
        core.shelves.sync([
            .init(
                display: display,
                edge: .top,
                strip: barTitleStrip,
                shelf: KiwiShelf(),
                sheen: 0,
                space: core.spaceBars.overlayForTesting(display),
                app: nil
            )
        ])
        let overlay = try #require(core.spaceBars.overlayForTesting(display))
        let item = try #require(overlay.itemViews.first { $0.space == two })
        let web = try #require(item.glyphTargets.first)
        try #require(web.members == [WindowID(4), WindowID(5)])
        return web
    }

    private func click(_ target: SpaceBarGlyphTarget) throws {
        let event = { (type: NSEvent.EventType) in
            NSEvent.mouseEvent(
                with: type,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        }
        target.mouseDown(with: try #require(event(.leftMouseDown)))
        target.mouseUp(with: try #require(event(.leftMouseUp)))
    }

    private func close(_ core: KiwiCore) {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
    }

    @Test("A list glyph's click shows its peek at once and pops no menu")
    func clickTogglesThePeek() throws {
        let core = seededCore()
        defer { close(core) }
        var menus = 0
        core.spaceBars.glyphActions.present = { _, _ in menus += 1 }
        var dwells = 0
        core.shelves.peek.schedule = { _, _ in dwells += 1 }
        let web = try webTarget(core)
        try click(web)
        #expect(menus == 0)
        #expect(dwells == 0, "no dwell")
        #expect(core.shelves.peek.shown?.view === web)
        #expect(
            core.shelves.peek.panel.drawn?.groups.flatMap(\.titles)
                == ["Doc", "Mail"]
        )
        #expect(core.activeSpace?.id == one, "nothing switches")
    }

    @Test("VoiceOver's press on a list glyph opens the menu once")
    func accessibilityPressOpensTheMenu() throws {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        defer { close(core) }
        var shown: [NSMenu] = []
        core.spaceBars.glyphActions.present = { menu, _ in
            shown.append(menu)
        }
        let web = try webTarget(core)
        #expect(web.accessibilityPerformPress())
        #expect(shown.count == 1)
        #expect(shown.first?.items.map(\.title) == ["Web", "Doc", "Mail"])
        #expect(core.shelves.peek.panel.drawn == nil, "no peek for it")
    }

    @Test("A peek row picks through Core: switch and focus")
    func peekRowPicks() throws {
        let core = seededCore()
        defer { close(core) }
        let web = try webTarget(core)
        try click(web)
        core.shelves.peek.panel.body.onPick(WindowID(5))
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces.lastFocused == WindowID(5))
        #expect(core.shelves.peek.panel.drawn == nil)
    }

    /// Judged when performed (#1925): the row was never greyed, and
    /// it does what its glyph's click does — a window the raise gate
    /// refuses takes the chip's plain switch, the one policy.
    @Test("A peek row the focus door refuses takes the plain switch")
    func refusedRowTakesThePlainSwitch() throws {
        let core = seededCore()
        defer { close(core) }
        // Space 2 remembers Web 5 while Notes 1 holds the focus, and
        // the gate refuses 4: the plain switch hands the focus to 5,
        // while a follow onto the refused 4 moves no focus at all
        // (the glyph's shape, `SpaceBarGlyphWiringTests`).
        core.state.workspaces.focus(WindowID(5), in: two)
        core.state.workspaces.focus(WindowID(1), in: one)
        core.windowIsOnScreen = { $0 == WindowID(4) ? false : nil }
        let web = try webTarget(core)
        try click(web)
        core.shelves.peek.panel.body.onPick(WindowID(4))
        #expect(core.activeSpace?.id == two, "the Space still switches")
        #expect(
            core.state.workspaces.lastFocused == WindowID(5),
            "the plain switch's focus, not a follow onto the refused"
        )
        #expect(core.shelves.peek.panel.drawn == nil)
    }

    /// The shelf panel's one press point: a press on the shelf off
    /// every glyph — the plate here, the divider's grip or a count
    /// alike — closes a peek the click showed; a press on the glyph
    /// itself waits for its release, which toggles.
    @Test("A press on the shelf off the glyph closes the peek")
    func pressOnTheShelfCloses() throws {
        let core = seededCore()
        defer { close(core) }
        let web = try webTarget(core)
        try click(web)
        let panel = try #require(web.window as? ShelfPanel)
        let content = try #require(panel.contentView)
        let press = { (point: CGPoint) throws -> NSEvent in
            try #require(
                NSEvent.mouseEvent(
                    with: .leftMouseDown,
                    location: point,
                    modifierFlags: [],
                    timestamp: 0,
                    windowNumber: panel.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: 1
                )
            )
        }
        let onGlyph = web.convert(
            CGPoint(x: web.bounds.midX, y: web.bounds.midY),
            to: nil
        )
        try #require(content.hitTest(onGlyph) === web)
        panel.sendEvent(try press(onGlyph))
        #expect(core.shelves.peek.panel.drawn != nil, "the glyph's own")
        let plate = CGPoint(x: content.bounds.maxX - 1, y: 1)
        let hit = content.hitTest(plate)
        try #require(!(hit is SpaceBarGlyphTarget))
        try #require(!(hit is SpaceBarItemView))
        panel.sendEvent(try press(plate))
        #expect(core.shelves.peek.panel.drawn == nil)
        #expect(core.activeSpace?.id == one, "nothing switches")
    }
}
