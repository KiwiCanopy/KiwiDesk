import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A click on a multi-window Space Bar glyph focuses its windows in
/// the peek's order (#2063, owner ruling): the one after the system
/// focus, wrapping, or the first where the focus is none of them —
/// derived from focus, never a stored position. `+n` keeps its
/// toggle, and the window menu checks the same window.
@Suite("Bar glyph click cycles", .serialized)
@MainActor
struct BarGlyphCycleTests {
    private let display = DisplayID(7)
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Space 1 shown and focused on Notes (1); Space 2 holds Mail
    /// 2, 3 and 4 and Web 5, its remembered focus on Mail 3.
    private func seededCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-cycle-\(UUID().uuidString)")
        )
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(two)
        for (id, app) in [(2, "Mail"), (3, "Mail"), (4, "Mail"), (5, "Web")] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: 100,
                        appName: app,
                        title: "W\(id)",
                        isFloating: false
                    )
                )
            )
        }
        core.state.apply(.windowFocused(WindowID(3)))
        core.state.workspaces.activate(one)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 100,
                    appName: "Notes",
                    title: "Memo",
                    isFloating: false
                )
            )
        )
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    private func pick(
        _ kind: SpaceBarGlyphPick.Kind = .glyph,
        _ ids: [UInt32] = [2, 3, 4]
    ) -> SpaceBarGlyphPick {
        SpaceBarGlyphPick(
            space: two,
            windows: ids.map(WindowID.init),
            kind: kind,
            anchor: NSView()
        )
    }

    @Test("Clicks walk the glyph's windows in the peek's order, wrapping")
    func clicksCycle() {
        let core = seededCore()
        // Another Space: the focus is none of them, so the first —
        // not the Space's remembered Mail 3 — and the Space switches.
        core.pickFromSpaceBar(pick())
        #expect(core.activeSpace?.id == two)
        #expect(core.state.workspaces.lastFocused == WindowID(2))
        core.pickFromSpaceBar(pick())
        #expect(core.state.workspaces.lastFocused == WindowID(3))
        core.pickFromSpaceBar(pick())
        #expect(core.state.workspaces.lastFocused == WindowID(4))
        core.pickFromSpaceBar(pick())
        #expect(core.state.workspaces.lastFocused == WindowID(2), "wraps")
    }

    /// No stored position: focus moved by anything else — a peek
    /// row, a key, a click on the window — is where the next click
    /// steps from.
    @Test("The next click steps from wherever the focus is")
    func cycleReadsFocus() {
        let core = seededCore()
        core.pickFromSpaceBar(pick())
        core.focusWindow(WindowID(4), warp: false)
        core.pickFromSpaceBar(pick())
        #expect(core.state.workspaces.lastFocused == WindowID(2))
        core.focusWindow(WindowID(5), warp: false)
        core.pickFromSpaceBar(pick())
        #expect(
            core.state.workspaces.lastFocused == WindowID(2),
            "focus on another app's window starts at the first"
        )
    }

    /// A playing Monocle flip owes its focus at its landing, so
    /// `lastFocused` still names the window it leaves: the click
    /// steps from the owed one, or a fast second click would land
    /// the same window again.
    @Test("An owed Monocle focus is the focus the click steps from")
    func owedMonocleFocusCounts() {
        let core = seededCore()
        core.pickFromSpaceBar(pick())
        core.pendingMonocleFocus = (
            from: WindowID(2), to: WindowID(3), warp: false
        )
        #expect(core.barFocus(on: two) == WindowID(3))
        #expect(core.glyphCycleTarget(pick()) == WindowID(4))
    }

    /// A window the focus door refuses (#1345) would leave the
    /// focus where it was, so the next click would pick it again
    /// and the walk would stall: the cycle steps over it.
    @Test("A window the focus door refuses is stepped over")
    func refusedWindowIsSteppedOver() {
        let core = seededCore()
        core.pickFromSpaceBar(pick())
        #expect(core.state.workspaces.lastFocused == WindowID(2))
        core.windowIsOnScreen = { $0 == WindowID(3) ? false : nil }
        core.pickFromSpaceBar(pick())
        #expect(core.state.workspaces.lastFocused == WindowID(4))
        core.pickFromSpaceBar(pick())
        #expect(core.state.workspaces.lastFocused == WindowID(2), "wraps")
    }

    /// A flip owes Web 5 while `lastFocused` still names Mail 2:
    /// the glyph's tint follows the list's check onto Web, so a
    /// glyph and its peek never name two windows.
    @Test("The glyph tint reads the owed Monocle focus too")
    func tintReadsTheOwedFocus() throws {
        let core = seededCore()
        core.pickFromSpaceBar(pick())
        core.pendingMonocleFocus = (
            from: WindowID(2), to: WindowID(5), warp: false
        )
        let item = try #require(
            core.spaceBarItems(display: display, style: SpaceBarLook())
                .first { $0.space == two }
        )
        let tinted = item.apps.filter(\.focused).map(\.name)
        #expect(tinted == ["Web"])
    }

    @Test("The focus counts only on the active Space")
    func focusGatedOnTheActiveSpace() {
        let core = seededCore()
        #expect(core.barFocus(on: one) == WindowID(1))
        #expect(core.barFocus(on: two) == nil)
        #expect(core.barFocus(on: nil) == WindowID(1), "an App Bar list")
    }

    @Test("+n keeps its toggle: a click switches and focuses nothing")
    func overflowStillToggles() {
        let core = seededCore()
        core.pickFromSpaceBar(pick(.overflow, [5]))
        core.pickFromSpaceBar(pick(.overflow, [4, 5]))
        #expect(core.activeSpace?.id == one)
        #expect(core.state.workspaces.lastFocused == WindowID(1))
    }

    @Test("A list's peek checks the focused window's row, a label none")
    func peekChecksTheFocusedRow() throws {
        let core = seededCore()
        let away = try #require(
            core.barPeekContent(.glyph([2, 3, 4].map(WindowID.init)), on: two)
        )
        #expect(away.checks)
        #expect(away.groups.flatMap(\.rows).allSatisfy { !$0.focused })
        core.pickFromSpaceBar(pick())
        let here = try #require(
            core.barPeekContent(.glyph([2, 3, 4].map(WindowID.init)), on: two)
        )
        #expect(
            here.groups.flatMap(\.rows).map(\.focused) == [true, false, false]
        )
        #expect(here.order == [2, 3, 4].map(WindowID.init))
        let label = try #require(
            core.barPeekContent(.glyph([WindowID(2)]), on: two)
        )
        #expect(!label.checks)
        #expect(!label.groups.flatMap(\.rows).contains { $0.focused })
    }

    @Test("The window menu checks the focused window natively")
    func menuTwinChecks() throws {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        core.pickFromSpaceBar(pick())
        var shown: NSMenu?
        core.spaceBars.glyphActions.present = { menu, _ in shown = menu }
        core.pressSpaceBarGlyph(pick())
        let menu = try #require(shown)
        #expect(menu.items.dropFirst().map(\.state) == [.on, .off, .off])
    }
}
