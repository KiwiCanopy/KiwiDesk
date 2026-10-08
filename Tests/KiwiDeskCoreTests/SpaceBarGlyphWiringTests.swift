import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// #1528's glyph targets end to end: a click on a target the real
/// render built reaches Core, the hover peek is asked of Core when
/// it shows (#1946), a
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
                edge: .top,
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

    private static let release = NSEvent.mouseEvent(
        with: .leftMouseUp,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 0
    )!

    @Test("A click on a rendered glyph reaches Core")
    func renderedClickReachesCore() throws {
        let core = seededCore()
        render(core)
        let web = try target(core, on: two)
        web.mouseDown(with: Self.click)
        web.mouseUp(with: Self.release)
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces.lastFocused == WindowID(4))
    }

    /// The target hands the peek its WINDOWS, never a string, so
    /// a title is whatever state holds when the peek shows (#1946).
    @Test("A rendered glyph's peek is read when it shows")
    func peekIsReadAtShow() throws {
        let core = seededCore()
        render(core)
        let web = try target(core, on: two)
        #expect(web.peekSource == .glyph([WindowID(4)]))
        let titles = {
            core.barPeekContent(web.peekSource)?.groups.flatMap(\.titles)
        }
        #expect(titles() == ["Doc"])
        core.state.windows.updateTitle(WindowID(4), title: "Renamed")
        #expect(titles() == ["Renamed"])
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

    @Test("A glyph the raise gate refuses still hands the Space over")
    func refusedGlyphFallsBackToTheSwitch() {
        let core = seededCore()
        core.state.workspaces.activate(two)
        core.state.apply(.windowCreated(window(5, app: "Term")))
        core.state.apply(.windowFocused(WindowID(5)))
        core.state.workspaces.activate(one)
        core.state.apply(.windowFocused(WindowID(1)))
        core.windowIsOnScreen = { $0 == WindowID(4) ? false : nil }
        core.focusFromSpaceBar(WindowID(4), on: two)
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces.lastFocused == WindowID(5))
    }

    @Test("A row the focus door would refuse is greyed, not hidden")
    func refusedRowIsGreyed() {
        let core = seededCore()
        core.windowIsOnScreen = { $0 == WindowID(4) ? false : nil }
        let rows = core.spaceBarMenuRows([WindowID(4), WindowID(1)])
        #expect(rows.map(\.row.window) == [WindowID(4), WindowID(1)])
        #expect(rows.map(\.enabled) == [false, true])
    }
}
