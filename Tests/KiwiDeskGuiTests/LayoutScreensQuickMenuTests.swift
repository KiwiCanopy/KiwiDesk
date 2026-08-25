import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Fake menu-bar slot so this suite never registers a real system
/// status item (#565 seam class); `StatusItemSeamGuardTests` pins
/// that every test construction injects one. A per-file stub by
/// convention — the status-item seam deliberately shares no
/// factory (`tests.md`).
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = nil
    var menu: NSMenu?
}

/// The Layout submenu once several screens are connected (#752).
///
/// `@MainActor` because `NSMenu` is, and **that is all this suite
/// does on the main actor**: it builds menus and reads their
/// items. No source scan, no filesystem walk, no layout pass. The
/// main actor is a budget shared with the heavy synchronous
/// scanning suites — they back it up past 30 s in a full run
/// (`tests.md` ▸ Async tests) — so a new `@MainActor` suite says
/// what it spends.
///
/// `.serialized` because titles are matched in English and
/// `LocalizationManager` is a process-wide singleton.
@Suite("Layout quick menu across screens (#752)", .serialized)
@MainActor
struct LayoutScreensQuickMenuTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        return core
    }

    private func makeController(
        _ core: KiwiCore
    ) -> StatusItemController {
        let controller = StatusItemController(
            item: FakeStatusItem()
        )
        controller.layoutInfoProvider = {
            LayoutMenuInfo.current(from: core)
        }
        return controller
    }

    /// Seed one screen holding one space, positioned at `x`.
    ///
    /// `x` is the ordering key the menu sorts on, so it is a
    /// parameter rather than a constant: the whole point of two
    /// screens is which one is drawn first.
    @discardableResult
    private func addScreen(
        to core: KiwiCore,
        id: UInt32,
        name: String,
        space: SpaceID,
        x: CGFloat,
        mode: LayoutMode
    ) -> DisplayID {
        let display = DisplayID(id)
        let frame = CGRect(x: x, y: 0, width: 1000, height: 800)
        core.state.workspaces.upsertDisplay(
            Display(
                id: display,
                name: name,
                frame: frame,
                visibleFrame: frame
            )
        )
        core.state.workspaces.ensureSpace(space)
        core.state.workspaces.assign(space, to: display)
        core.state.workspaces.setMode(space, mode)
        return display
    }

    private func modeRows(_ menu: NSMenu) -> [NSMenuItem] {
        menu.items.filter {
            $0.representedObject is LayoutMenuTarget
        }
    }

    private func checked(_ menu: NSMenu) -> [LayoutMode] {
        modeRows(menu)
            .filter { $0.state == .on }
            .compactMap {
                ($0.representedObject as? LayoutMenuTarget)?.mode
            }
    }

    @Test("Two screens nest: All Screens, then a row per screen")
    func nestsWithTwoScreens() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        addScreen(
            to: core,
            id: 1,
            name: "Left",
            space: SpaceID("1"),
            x: 0,
            mode: .bsp
        )
        addScreen(
            to: core,
            id: 2,
            name: "Right",
            space: SpaceID("2"),
            x: 1000,
            mode: .grid
        )
        let controller = makeController(core)
        let submenu = try #require(controller.layoutItem().submenu)

        // The top level holds no mode rows at all any more —
        // every pick moved one level down.
        #expect(modeRows(submenu).isEmpty)
        let nested = submenu.items.filter { $0.submenu != nil }
        // All Screens + one per screen.
        #expect(nested.count == 3)
        #expect(nested.first?.title == "All Screens")
        #expect(nested.map(\.title).contains("Left"))
        #expect(nested.map(\.title).contains("Right"))
        // A separator divides the collective row from the
        // per-screen ones.
        #expect(submenu.items.contains { $0.isSeparatorItem })
    }

    @Test("Each screen's checkmark answers for its own space")
    func checkmarkIsPerScreen() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        addScreen(
            to: core,
            id: 1,
            name: "Left",
            space: SpaceID("1"),
            x: 0,
            mode: .bsp
        )
        addScreen(
            to: core,
            id: 2,
            name: "Right",
            space: SpaceID("2"),
            x: 1000,
            mode: .monocle
        )
        let controller = makeController(core)
        let submenu = try #require(controller.layoutItem().submenu)
        let left = try #require(
            submenu.items.first { $0.title == "Left" }?.submenu
        )
        let right = try #require(
            submenu.items.first { $0.title == "Right" }?.submenu
        )
        // Each screen reports ITS space's mode — the defect this
        // guards is one screen's mode being read for both, which
        // a single-mode fixture cannot see.
        #expect(checked(left) == [.bsp])
        #expect(checked(right) == [.monocle])
    }

    @Test("A screen row carries the space it will set")
    func rowsTargetTheirOwnSpace() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        addScreen(
            to: core,
            id: 1,
            name: "Left",
            space: SpaceID("1"),
            x: 0,
            mode: .bsp
        )
        addScreen(
            to: core,
            id: 2,
            name: "Right",
            space: SpaceID("7"),
            x: 1000,
            mode: .grid
        )
        let controller = makeController(core)
        let submenu = try #require(controller.layoutItem().submenu)
        let right = try #require(
            submenu.items.first { $0.title == "Right" }?.submenu
        )
        let scopes = modeRows(right).compactMap {
            ($0.representedObject as? LayoutMenuTarget)?.scope
        }
        #expect(scopes.count == LayoutMode.allCases.count)
        // Every row on that screen's submenu names that screen's
        // space — not the active one, which is what a bare
        // `set_mode` would have written.
        for scope in scopes {
            guard case .space(let id) = scope else {
                Issue.record("expected .space, got \(scope)")
                continue
            }
            #expect(id == SpaceID("7"))
        }
    }

    @Test("One screen keeps the flat menu and the active-space scope")
    func oneScreenStaysFlat() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        addScreen(
            to: core,
            id: 1,
            name: "Only",
            space: SpaceID("1"),
            x: 0,
            mode: .bsp
        )
        let controller = makeController(core)
        let submenu = try #require(controller.layoutItem().submenu)
        #expect(modeRows(submenu).count == LayoutMode.allCases.count)
        #expect(submenu.items.allSatisfy { $0.submenu == nil })
        // The extra level costs a click on the app's most-used
        // control, so one screen must not pay it — and the rows
        // keep the active-space scope, so nothing starts naming a
        // space where it did not before.
        for row in modeRows(submenu) {
            let scope =
                (row.representedObject as? LayoutMenuTarget)?.scope
            guard case .activeSpace = scope else {
                Issue.record("expected .activeSpace")
                continue
            }
        }
    }

    @Test("Every nested menu keeps manual enablement (#802)")
    func nestedMenusStateEnablement() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        addScreen(
            to: core,
            id: 1,
            name: "Left",
            space: SpaceID("1"),
            x: 0,
            mode: .bsp
        )
        addScreen(
            to: core,
            id: 2,
            name: "Right",
            space: SpaceID("2"),
            x: 1000,
            mode: .grid
        )
        let controller = makeController(core)
        let submenu = try #require(controller.layoutItem().submenu)
        #expect(!submenu.autoenablesItems)
        // Assert the loop below has something to walk BEFORE
        // walking it. `guard-prover` broke the nesting (2026-08-17)
        // and this test passed on `!autoenablesItems` alone, its
        // `where` clause matching nothing — green having checked
        // nothing about a nested menu.
        let nestedRows = submenu.items.filter { $0.submenu != nil }
        #expect(nestedRows.count == 3)
        for parent in submenu.items where parent.submenu != nil {
            let nested = try #require(parent.submenu)
            // Each new NSMenu turns it off for itself — the flag
            // does not inherit, and a nested menu left on
            // auto-enable would re-enable rows at display time.
            #expect(!nested.autoenablesItems)
            // With the flag off nothing is enabled for free, the
            // submenu parent included.
            #expect(parent.isEnabled)
            #expect(nested.items.allSatisfy { $0.isEnabled })
        }
    }
}
