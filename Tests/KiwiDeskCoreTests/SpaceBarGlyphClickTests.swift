import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A click on a Space Bar glyph or `+n` (#1528, rulings 8–10): a
/// one-window glyph switches to its Space AND lands on that
/// window; a group glyph and `+n` list their windows — the peek on
/// a click, the native menu for VoiceOver (#1946) — and switch
/// nothing until a row is picked.
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
        if let cap { look.glyphSpan = cap }
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

    @Test("each +n carries its side's windows, in row order")
    func overflowCarriesItsWindows() throws {
        let core = seededCore()
        core.state.workspaces.activate(two)
        core.state.apply(.windowCreated(window(5, app: "Term")))
        core.state.apply(.windowCreated(window(6, app: "Term")))
        core.state.apply(.windowFocused(WindowID(4)))
        core.state.apply(.windowCreated(window(7, app: "Zed")))
        core.state.workspaces.activate(one)
        // New windows land after the focused one, so the row is
        // Mail 2 · Term 5 6 · Mail 3 · Web 4 · Zed 7. A strip held
        // on Mail 3 hides two groups on each side, one of them of
        // several windows (#1528 items 17, 21; a disc hides two
        // groups or more, #2052).
        core.spaceBars.stripHover(
            two,
            .init(window: 2..<3, count: 5),
            inside: true
        )
        let built = try item(core, two, cap: 1)
        #expect(built.apps.map(\.windows) == [[WindowID(3)]])
        #expect(
            built.before.windows
                == [WindowID(2), WindowID(5), WindowID(6)]
        )
        #expect(built.after.windows == [WindowID(4), WindowID(7)])
        #expect(built.discs == 2)
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

    /// A click on a list opens no menu — the peek is its list
    /// (`BarPeekClickTests`) — while VoiceOver's press opens the
    /// native menu, the peek's accessible twin (#1946).
    @Test("A group glyph's click opens no menu; VoiceOver's press does")
    func groupOpensAMenuForVoiceOver() throws {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        let menu = capturingMenus(core)
        core.pickFromSpaceBar(pick([2, 3], on: two))
        #expect(menu() == nil, "a click shows the peek instead")
        #expect(core.activeSpace?.id == one)
        core.pressSpaceBarGlyph(pick([2, 3], on: two))
        #expect(core.activeSpace?.id == one)
        let shown = try #require(menu())
        // One app's rows: titles under an app header (#1947).
        #expect(shown.items.map(\.title) == ["Mail", "Inbox", "Draft"])
        #expect(shown.items[0].isSectionHeader)
        // Icons stand down on glyph rows: `untitledGlyphRow`, since
        // this fixture's windows have no icon to drop.
        let enabled = shown.items.dropFirst().allSatisfy { $0.isEnabled }
        #expect(enabled)
        pickRow(shown, at: 2)
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces[two]?.focused == WindowID(3))
    }

    @Test("+n's VoiceOver menu lists even one window, switching nothing")
    func overflowOpensAMenuForVoiceOver() throws {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        let menu = capturingMenus(core)
        core.pickFromSpaceBar(pick([4], on: two, .overflow))
        #expect(menu() == nil, "a click shows the peek instead")
        core.pressSpaceBarGlyph(pick([4], on: two, .overflow))
        #expect(core.activeSpace?.id == one)
        let shown = try #require(menu())
        // Mixed apps: no header, each row names its app.
        #expect(shown.items.map(\.title) == ["Web — Doc"])
        pickRow(shown, at: 0)
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces[two]?.focused == WindowID(4))
    }

    @Test("The right-click names an untitled window as the glyph menu")
    func rightClickNamesUntitledAlike() {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        core.state.apply(.windowCreated(window(8, app: "Web", title: "")))
        #expect(core.windowRowName(WindowID(8)) == "Untitled Window")
        // A pill names the window outside its app's menu.
        #expect(core.windowTitle(WindowID(8)) == "Web")
        // Every per-window submenu takes the row name: move, float
        // and close each list window 8 as the placeholder.
        let rows = core.barMenuRows(.glyph([WindowID(4), WindowID(8)]))
        let untitled = rows.compactMap { row -> String? in
            guard case .submenu(let items) = row.kind,
                items.count == 2
            else { return nil }
            return items[1].title
        }
        #expect(untitled == Array(repeating: "Untitled Window", count: 3))
    }

    /// Every window counts (#1946): an untitled one is a row named
    /// as the glyph menu names it.
    @Test("The peek lists every window under its app")
    func peekListsEveryWindow() throws {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        let mail = try #require(
            core.barPeekContent(.glyph([WindowID(2), WindowID(3)]))
        )
        #expect(mail.groups.map(\.app) == ["Mail"])
        #expect(mail.groups.map(\.titles) == [["Inbox", "Draft"]])
        #expect(mail.groups.map(\.windowCount) == [2])
        let web = try #require(core.barPeekContent(.glyph([WindowID(4)])))
        #expect(web.groups.map(\.titles) == [["Doc"]])
        core.state.windows.updateTitle(WindowID(3), title: "")
        let untitled = try #require(
            core.barPeekContent(.glyph([WindowID(2), WindowID(3)]))
        )
        #expect(
            untitled.groups.map(\.titles) == [["Inbox", "Untitled Window"]]
        )
        #expect(core.barPeekContent(.glyph([WindowID(99)])) == nil)
    }

    @Test("The bootstrap wires the targets to the click routing")
    func bootstrapWiresThePick() throws {
        let core = seededCore()
        core.spaceBars.glyphActions.pick(pick([4], on: two))
        #expect(core.activeSpace?.id == two)
        let peek = try #require(core.spaceBars.glyphActions.peek)
        #expect(
            peek.content(.glyph([WindowID(4)]))?.groups.map(\.titles)
                == [["Doc"]]
        )
    }

}
