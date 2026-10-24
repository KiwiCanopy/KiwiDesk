import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A click on a multi-window Space Bar glyph or `+n` opens its list
/// and moves no focus (#2571, retiring #2063's cycle); a list checks
/// the focused window's row, and the window menu checks the same
/// window.
@Suite("Bar glyph clicks and the focus check", .serialized)
@MainActor
struct BarGlyphClickTests {
    private let display = DisplayID(7)
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Space 1 shown and focused on Notes (1); Space 2 holds Mail
    /// 2, 3 and 4 and Web 5, its remembered focus on Mail 3.
    private func seededCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
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

    /// The list opens first and a row picks (#2571, owner
    /// 2026-10-24): repeated clicks neither switch nor walk.
    @Test("A multi-window glyph's click switches and focuses nothing")
    func glyphClickFocusesNothing() {
        let core = seededCore()
        core.pickFromSpaceBar(pick())
        core.pickFromSpaceBar(pick())
        #expect(core.activeSpace?.id == one)
        #expect(core.state.workspaces.lastFocused == WindowID(1))
    }

    @Test("The focus counts only on the active Space")
    func focusGatedOnTheActiveSpace() {
        let core = seededCore()
        #expect(core.barFocus(on: one) == WindowID(1))
        #expect(core.barFocus(on: two) == nil)
        #expect(core.barFocus(on: nil) == WindowID(1), "an App Bar list")
    }

    @Test("A +n click switches and focuses nothing")
    func overflowFocusesNothing() {
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
        core.pickBarRow(WindowID(2), on: two)
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
        core.pickBarRow(WindowID(2), on: two)
        var shown: NSMenu?
        core.spaceBars.glyphActions.present = { menu, _ in shown = menu }
        core.pressSpaceBarGlyph(pick())
        let menu = try #require(shown)
        #expect(menu.items.dropFirst().map(\.state) == [.on, .off, .off])
    }
}
