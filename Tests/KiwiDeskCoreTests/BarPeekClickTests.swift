import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A click on a rendered list glyph (#1946, owner ruling amendment
/// 2): it pins the peek at once and presents no menu, VoiceOver's
/// press presents the native menu once, and a peek row picks
/// through Core's one bar-row pick — the window menu's — refusing a
/// window on an unshown Desktop with a cue rather than a switch.
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

    @Test("A list glyph's click pins its peek at once and pops no menu")
    func clickPinsThePeek() throws {
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
        #expect(core.shelves.peek.pinned)
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

    /// Judged when performed (#1925): the row was never greyed, so
    /// the refusal is a cue, and nothing switches.
    @Test("A peek row the focus door refuses cues and switches nothing")
    func refusedRowCues() throws {
        let core = seededCore()
        defer { close(core) }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.windowIsOnScreen = { $0 == WindowID(5) ? false : nil }
        let web = try webTarget(core)
        try click(web)
        core.shelves.peek.panel.body.onPick(WindowID(5))
        #expect(core.activeSpace?.id == one)
        #expect(log.contains("bar row on an unshown Desktop: w5"))
    }
}
