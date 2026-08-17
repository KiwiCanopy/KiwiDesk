import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Fake menu-bar slot so this suite never registers a real system
/// status item (#565 seam class). A per-file stub, duplicated from
/// its sibling by convention — the status-item seam deliberately
/// shares no factory, and `StatusItemSeamGuardTests` pins every
/// construction route instead (`tests.md`).
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = nil
    var menu: NSMenu?
}

/// The collective **All Screens** row, and the ordering the
/// per-screen rows are drawn in (#752).
///
/// Split from `LayoutScreensQuickMenuTests` at the §2.1 ceiling
/// rather than for a conceptual reason, but the seam is a real
/// one: that suite asks what one screen's row does, and this asks
/// about the list as a whole.
///
/// `@MainActor` because `NSMenu` is, and that is all it spends
/// there — menus built, items read, no scan and no filesystem
/// walk. The main actor is a budget shared with the heavy
/// synchronous scanning suites, so a new one says what it costs.
///
/// `.serialized` because titles are matched in English and
/// `LocalizationManager` is a process-wide singleton.
@Suite("Layout quick menu: All Screens and order (#752)", .serialized)
@MainActor
struct LayoutAllScreensTests {
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

    /// Seed one screen holding one space, positioned at `x` — the
    /// ordering key, so it is a parameter rather than a constant.
    private func addScreen(
        to core: KiwiCore,
        id: UInt32,
        name: String,
        space: SpaceID,
        x: CGFloat,
        mode: LayoutMode
    ) {
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
    }

    /// Two screens, seeded RIGHT first so insertion order and the
    /// wanted order disagree.
    private func twoScreens(_ core: KiwiCore) {
        addScreen(
            to: core,
            id: 2,
            name: "Right",
            space: SpaceID("2"),
            x: 1000,
            mode: .grid
        )
        addScreen(
            to: core,
            id: 1,
            name: "Left",
            space: SpaceID("1"),
            x: 0,
            mode: .bsp
        )
    }

    private func modeRows(_ menu: NSMenu) -> [NSMenuItem] {
        menu.items.filter {
            $0.representedObject is LayoutMenuTarget
        }
    }

    private func allScreensMenu(
        _ controller: StatusItemController
    ) throws -> NSMenu {
        let submenu = try #require(controller.layoutItem().submenu)
        return try #require(
            submenu.items.first {
                $0.title == "All Screens"
            }?.submenu
        )
    }

    @Test("Screens draw left to right, not in Dictionary order")
    func screensSortByPosition() {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        twoScreens(core)
        // `allDisplays` is `Array(displays.values)` — a
        // Dictionary's values, whose order is unspecified — so
        // nothing but the sort puts these right, and drawn
        // unsorted the rows shuffle between two opens with nothing
        // about the machine having changed.
        let info = LayoutMenuInfo.current(from: core)
        #expect(
            info.orderedScreens.map(\.name) == ["Left", "Right"]
        )
    }

    @Test("The ordering key is position, not insertion or name")
    func orderingIsPositional() {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        // Names sort the OPPOSITE way to positions here, so a sort
        // that fell back to the label would answer ["Alpha",
        // "Zulu"] and this discriminates the two rules.
        addScreen(
            to: core,
            id: 1,
            name: "Zulu",
            space: SpaceID("1"),
            x: 0,
            mode: .bsp
        )
        addScreen(
            to: core,
            id: 2,
            name: "Alpha",
            space: SpaceID("2"),
            x: 1000,
            mode: .grid
        )
        let info = LayoutMenuInfo.current(from: core)
        #expect(
            info.orderedScreens.map(\.name) == ["Zulu", "Alpha"]
        )
    }

    @Test("All Screens offers every mode and claims none")
    func allScreensRow() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        twoScreens(core)
        let all = try allScreensMenu(makeController(core))

        #expect(modeRows(all).count == LayoutMode.allCases.count)
        // No checkmark anywhere: a tick here would have to mean
        // "every screen already runs this", which is a different
        // claim from any one screen's mode and would read as the
        // state of a thing that has no single state.
        #expect(modeRows(all).allSatisfy { $0.state == .off })
        for row in modeRows(all) {
            let target =
                row.representedObject as? LayoutMenuTarget
            guard case .everyScreen = target?.scope else {
                Issue.record("expected .everyScreen")
                continue
            }
        }
    }

    @Test("Picking All Screens sets every screen's own space")
    func allScreensAppliesToEach() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        twoScreens(core)
        let controller = makeController(core)
        var applied: [(mode: LayoutMode, space: SpaceID?)] = []
        controller.onSetLayoutMode = { mode, space in
            applied.append((mode, space))
        }
        let all = try allScreensMenu(controller)
        let monocle = try #require(
            modeRows(all).first {
                ($0.representedObject as? LayoutMenuTarget)?.mode
                    == .monocle
            }
        )

        controller.setLayoutMode(monocle)

        #expect(applied.count == 2)
        #expect(applied.allSatisfy { $0.mode == .monocle })
        // Each space NAMED, never the nil that means "the active
        // one": a loop passing nil twice would set the focused
        // space twice and leave the other screen untouched, while
        // still firing the right number of times.
        #expect(
            Set(applied.compactMap(\.space))
                == [SpaceID("1"), SpaceID("2")]
        )
    }
}
