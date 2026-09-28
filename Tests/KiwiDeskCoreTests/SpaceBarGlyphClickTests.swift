import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A click on a Space Bar glyph or `+n` (#1528, rulings 8–10): a
/// one-window glyph switches to its Space AND lands on that
/// window; a group glyph and `+n` open a menu and switch nothing
/// until a row is picked.
@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-glyph-click-\(UUID().uuidString)"
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

@Suite("Space bar glyph click", .serialized)
@MainActor
struct SpaceBarGlyphClickTests {
    private let display = DisplayID(7)
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Space 1 shown and focused on Notes (1). Space 2 holds a
    /// Mail run (2, 3) and Web (4), its remembered focus on Mail 2.
    private func seededCore() -> KiwiCore {
        let core = makeCore()
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(two)
        core.state.apply(
            .windowCreated(window(2, app: "Mail", title: "Inbox"))
        )
        core.state.apply(
            .windowCreated(window(3, app: "Mail", title: "Draft"))
        )
        core.state.apply(.windowCreated(window(4, app: "Web")))
        core.state.apply(.windowFocused(WindowID(2)))
        core.state.workspaces.activate(one)
        core.state.apply(.windowCreated(window(1, app: "Notes")))
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    private func item(
        _ core: KiwiCore,
        _ space: SpaceID,
        cap: Int? = nil
    ) throws -> SpaceBarOverlay.Item {
        var look = SpaceBarLook()
        if let cap { look.glyphCap = cap }
        return try #require(
            core.spaceBarItems(display: display, style: look)
                .first { $0.space == space }
        )
    }

    private func pick(
        _ windows: [UInt32],
        on space: SpaceID,
        _ kind: SpaceBarGlyphPick.Kind = .glyph
    ) -> SpaceBarGlyphPick {
        SpaceBarGlyphPick(
            space: space,
            windows: windows.map(WindowID.init),
            kind: kind,
            anchor: NSView()
        )
    }

    /// Fires a row's action through its own target and selector:
    /// `performActionForItem` needs an `NSApplication`, which a
    /// suite run alone has not made.
    private func pickRow(_ menu: NSMenu, at index: Int) {
        let row = menu.items[index]
        _ = (row.target as? NSObject)?.perform(row.action, with: row)
    }

    /// Captures the menu a pick presents instead of popping it.
    private func capturingMenus(_ core: KiwiCore) -> () -> NSMenu? {
        var shown: NSMenu?
        core.spaceBars.glyphActions.present = { menu, _ in
            shown = menu
        }
        return { shown }
    }

    @Test("Each glyph carries the windows it stands for")
    func glyphsCarryTheirWindows() throws {
        let built = try item(seededCore(), two)
        #expect(
            built.apps.map(\.windows)
                == [[WindowID(2), WindowID(3)], [WindowID(4)]]
        )
        #expect(built.apps.map(\.count) == [2, 1])
    }

    @Test("+n carries the windows past the cap, in row order")
    func overflowCarriesItsWindows() throws {
        let core = seededCore()
        core.state.workspaces.activate(two)
        core.state.apply(.windowCreated(window(5, app: "Term")))
        core.state.apply(.windowCreated(window(6, app: "Term")))
        core.state.workspaces.activate(one)
        // New windows land after the focused Mail 2, so the row
        // is Mail 2 · Term 5 6 · Mail 3 · Web 4: three hidden
        // groups past the cap, the first of several windows.
        let built = try item(core, two, cap: 1)
        #expect(
            built.overflowWindows
                == [WindowID(5), WindowID(6), WindowID(3), WindowID(4)]
        )
        #expect(built.overflow == 4)
    }

    @Test("A glyph on an inactive Space switches and lands on it")
    func inactiveGlyphSwitchesAndFocuses() {
        let core = seededCore()
        core.pickFromSpaceBar(pick([4], on: two))
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces[two]?.focused == WindowID(4))
        #expect(core.state.workspaces.lastFocused == WindowID(4))
    }

    @Test("A glyph on the active Space focuses without a switch")
    func activeGlyphFocuses() {
        let core = seededCore()
        core.state.apply(.windowCreated(window(5, app: "Term")))
        core.state.apply(.windowFocused(WindowID(1)))
        core.pickFromSpaceBar(pick([5], on: one))
        #expect(core.activeSpace?.id == one)
        #expect(core.state.workspaces[one]?.focused == WindowID(5))
    }

    @Test("A group glyph opens its menu and switches nothing")
    func groupOpensAMenu() throws {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        let menu = capturingMenus(core)
        core.pickFromSpaceBar(pick([2, 3], on: two))
        #expect(core.activeSpace?.id == one)
        let shown = try #require(menu())
        #expect(
            shown.items.map(\.title)
                == ["Mail — Inbox", "Mail — Draft"]
        )
        #expect(shown.items.allSatisfy { $0.isEnabled })
        pickRow(shown, at: 1)
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces[two]?.focused == WindowID(3))
    }

    @Test("+n opens its menu even for one window, switching nothing")
    func overflowOpensAMenu() throws {
        let core = seededCore()
        let menu = capturingMenus(core)
        core.pickFromSpaceBar(pick([4], on: two, .overflow))
        #expect(core.activeSpace?.id == one)
        let shown = try #require(menu())
        #expect(shown.items.count == 1)
        pickRow(shown, at: 0)
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces[two]?.focused == WindowID(4))
    }

    @Test("A long title is cut in the row and whole in its tooltip")
    func longTitleIsCut() {
        LocalizationManager.shared.select("en")
        let long = String(
            repeating: "x",
            count: SpaceBarWindowMenu.titleCap + 5
        )
        let row = SpaceBarWindowMenu.Row(
            window: WindowID(9),
            app: "Web",
            title: long,
            icon: nil,
            enabled: false
        )
        let menu = SpaceBarWindowMenu.make([row]) { _ in }
        let item = menu.items[0]
        #expect(item.title.hasSuffix("…"))
        #expect(item.toolTip == long)
        #expect(!item.isEnabled)
        let short = SpaceBarWindowMenu.make(
            [
                .init(
                    window: WindowID(9),
                    app: "Web",
                    title: "",
                    icon: nil,
                    enabled: true
                )
            ]
        ) { _ in }
        #expect(short.items[0].isEnabled)
        #expect(short.items[0].title == "Web")
        #expect(short.items[0].toolTip == nil)
        let titled = SpaceBarWindowMenu.make(
            [
                .init(
                    window: WindowID(9),
                    app: "Web",
                    title: "Inbox",
                    icon: nil,
                    enabled: true
                )
            ]
        ) { _ in }
        #expect(titled.items[0].toolTip == nil)
    }

    @Test("The hover title is the app, then each window's title")
    func tooltipListsTitles() {
        let core = seededCore()
        #expect(
            core.spaceBarTooltip([WindowID(2), WindowID(3)])
                == "Mail\nInbox\nDraft"
        )
        #expect(core.spaceBarTooltip([WindowID(4)]) == "Web\nDoc")
        #expect(core.spaceBarTooltip([WindowID(99)]) == nil)
    }

    @Test("The bootstrap wires the targets to the click routing")
    func bootstrapWiresThePick() {
        let core = seededCore()
        core.spaceBars.glyphActions.pick(pick([4], on: two))
        #expect(core.activeSpace?.id == two)
        #expect(
            core.spaceBars.glyphActions.tooltip([WindowID(4)])
                == "Web\nDoc"
        )
    }
}
