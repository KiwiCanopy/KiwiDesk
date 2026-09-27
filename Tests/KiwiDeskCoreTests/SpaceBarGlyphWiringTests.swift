import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// #1528's glyph targets end to end: a click on a target the real
/// render built reaches Core, the hover title is asked of Core when
/// it shows, the shelf panel lets it show in an inactive app, a
/// traveler's glyph lands on the traveler, a stale menu pick is
/// dropped, and a row the focus door refuses is greyed. Split from
/// `SpaceBarGlyphClickTests` for the file ceiling.
@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-glyph-wiring-\(UUID().uuidString)"
            )
    )
}

private func window(
    _ id: UInt32,
    app: String,
    title: String = "Doc"
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: app,
        title: title,
        isFloating: false
    )
}

@Suite("Space bar glyph wiring", .serialized)
@MainActor
struct SpaceBarGlyphWiringTests {
    private let display = barTitleDisplay
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    init() {
        LiquidGlassGate.override = { false }
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    /// Space 1 active on Notes (1); Space 2 holds Web (4).
    private func seededCore() -> KiwiCore {
        let core = makeCore()
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(two)
        core.state.apply(.windowCreated(window(4, app: "Web")))
        core.state.workspaces.activate(one)
        core.state.apply(.windowCreated(window(1, app: "Notes")))
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    /// One render and placement of the Space Bar, `updateBars`'
    /// order, from the items Core builds.
    private func render(_ core: KiwiCore) {
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
                strip: barTitleStrip,
                shelf: KiwiShelf(),
                sheen: 0,
                space: core.spaceBars.overlayForTesting(display),
                app: nil
            )
        ])
    }

    private func target(
        _ core: KiwiCore,
        on space: SpaceID
    ) throws -> SpaceBarGlyphTarget {
        let overlay = try #require(
            core.spaceBars.overlayForTesting(display)
        )
        let item = try #require(
            overlay.itemViews.first { $0.space == space }
        )
        return try #require(item.glyphTargets.first)
    }

    private static let click = NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!

    @Test("A click on a rendered glyph reaches Core")
    func renderedClickReachesCore() throws {
        let core = seededCore()
        render(core)
        try target(core, on: two).mouseDown(with: Self.click)
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces.lastFocused == WindowID(4))
    }

    @Test("A rendered glyph asks Core for its title when it shows")
    func tooltipIsReadAtHover() throws {
        let core = seededCore()
        render(core)
        let web = try target(core, on: two)
        let tip = {
            web.view(
                web,
                stringForToolTip: 0,
                point: .zero,
                userData: nil
            )
        }
        #expect(tip() == "Web\nDoc")
        core.state.windows.updateTitle(WindowID(4), title: "Renamed")
        #expect(tip() == "Web\nRenamed")
    }

    @Test("The shelf panel shows tooltips while KiwiDesk is inactive")
    func panelAllowsInactiveTooltips() throws {
        let core = seededCore()
        render(core)
        let shelf = try #require(core.shelves.overlayForTesting(display))
        let panel = try #require(shelf.panel)
        #expect(panel.allowsToolTipsWhenApplicationIsInactive)
    }

    @Test("A traveler's glyph lands on the traveler, not its home")
    func travelerLandsOnItself() throws {
        let other = DisplayID(8)
        let core = seededCore()
        core.state.workspaces.assign(SpaceID("3"), to: other)
        core.state.workspaces.assign(SpaceID("4"), to: other)
        core.state.workspaces.activate(SpaceID("4"))
        core.state.apply(.windowCreated(window(8, app: "Pin")))
        core.state.workspaces.activate(SpaceID("3"))
        core.state.apply(.windowCreated(window(9, app: "Term")))
        core.state.apply(.windowFocused(WindowID(9)))
        core.state.workspaces.activate(one)
        core.state.setSticky(WindowID(8), .display)
        // Homed on hidden Space 4, drawn on Space 3, the Space
        // the other screen shows.
        let shown = try #require(
            core.spaceBarItems(display: other, style: SpaceBarLook())
                .first { $0.space == SpaceID("3") }
        )
        try #require(shown.apps.contains { $0.windows == [WindowID(8)] })
        core.pickFromSpaceBar(
            SpaceBarGlyphPick(
                space: SpaceID("3"),
                windows: [WindowID(8)],
                kind: .glyph,
                anchor: NSView()
            )
        )
        #expect(core.activeSpace?.id == SpaceID("3"))
        #expect(core.state.workspaces.lastFocused == WindowID(8))
    }

    @Test("A menu pick whose window left the Space is dropped")
    func stalePickIsDropped() {
        let core = seededCore()
        core.state.workspaces.add(WindowID(4), to: one)
        core.focusFromSpaceBar(WindowID(4), on: two)
        #expect(core.activeSpace?.id == one)
        #expect(core.state.workspaces.lastFocused == WindowID(1))
    }

    @Test("A row the focus door would refuse is greyed, not hidden")
    func refusedRowIsGreyed() {
        let core = seededCore()
        core.windowIsOnScreen = { $0 == WindowID(4) ? false : nil }
        let rows = core.spaceBarMenuRows([WindowID(4), WindowID(1)])
        #expect(rows.map(\.window) == [WindowID(4), WindowID(1)])
        #expect(rows.map(\.enabled) == [false, true])
    }
}
