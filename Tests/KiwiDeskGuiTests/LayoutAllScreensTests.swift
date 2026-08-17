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

    /// A screen at `x`, with no core and no Dictionary involved.
    private func screen(
        _ name: String,
        x: CGFloat
    ) -> LayoutMenuInfo.Screen {
        LayoutMenuInfo.Screen(
            space: SpaceID(name),
            name: name,
            id: DisplayID(UInt32(abs(Int(x)) % 1000 + 1)),
            origin: CGPoint(x: x, y: 0),
            mode: .bsp,
            savedMode: nil
        )
    }

    /// The sort itself, on a hand-built value.
    ///
    /// **This is the deterministic half, and it exists because the
    /// derivation-level test below is not.** `allDisplays` is
    /// `Array(displays.values)` and Swift seeds Dictionary hashing
    /// per process, so a fixture cannot force the wrong source
    /// order: `guard-prover` measured a dropped sort going red on
    /// only 6 of 10 isolated runs (2026-08-17), i.e. shipping green
    /// about 40% of the time with CI as the coin flip. Building the
    /// value directly takes the Dictionary out of it — the input
    /// order is now stated by the test, so a lost sort always reds.
    @Test("orderedScreens sorts by position, deterministically")
    func orderedScreensSorts() {
        let info = LayoutMenuInfo(
            activeMode: nil,
            activeProfileName: nil,
            savedModeForActiveSpace: nil,
            screens: [screen("Right", x: 1000), screen("Left", x: 0)]
        )
        #expect(
            info.orderedScreens.map(\.name) == ["Left", "Right"]
        )
    }

    /// The vertical half of the key, which the two-screen desk
    /// fixtures cannot reach — they all sit at y=0.
    ///
    /// **The coordinates are AppKit's, where y grows UP**, so the
    /// screen physically ABOVE has the LARGER `minY`. An earlier
    /// cut of this test named y=900 "Lower" and so pinned the
    /// inverted convention it was written to guard — a fixture
    /// agreeing with the bug (`code-reviewer`, 2026-08-17).
    @Test("Screens at one x sort top to bottom")
    func orderedScreensBreaksTiesVertically() {
        let lower = LayoutMenuInfo.Screen(
            space: SpaceID("lower"),
            name: "Lower",
            id: DisplayID(2),
            origin: CGPoint(x: 0, y: 0),
            mode: .bsp,
            savedMode: nil
        )
        let upper = LayoutMenuInfo.Screen(
            space: SpaceID("upper"),
            name: "Upper",
            id: DisplayID(1),
            origin: CGPoint(x: 0, y: 900),
            mode: .bsp,
            savedMode: nil
        )
        let info = LayoutMenuInfo(
            activeMode: nil,
            activeProfileName: nil,
            savedModeForActiveSpace: nil,
            screens: [lower, upper]
        )
        #expect(
            info.orderedScreens.map(\.name) == ["Upper", "Lower"]
        )
    }

    @Test("The sort is applied to what the core hands over")
    func screensSortByPosition() {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        twoScreens(core)
        // The other half: that `current(from:)` routes through the
        // sort at all. It cannot prove the sort WORKS — the source
        // order here is a Dictionary's and may already be right —
        // so `orderedScreensSorts` above owns that, and this owns
        // the wiring.
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

    @Test("A screen unplugged after the menu opened is skipped")
    func unpluggedScreenIsNotWrittenTo() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        twoScreens(core)
        let controller = makeController(core)
        var applied: [SpaceID?] = []
        controller.onSetLayoutMode = { _, space in
            applied.append(space)
        }
        let all = try allScreensMenu(controller)
        let monocle = try #require(
            modeRows(all).first {
                ($0.representedObject as? LayoutMenuTarget)?.mode
                    == .monocle
            }
        )

        // Unplug "Right" AFTER the menu was built, before the pick
        // lands — the window a real user hits by leaving a menu
        // open on a laptop that then undocks.
        core.state.workspaces.removeDisplay(DisplayID(2))

        controller.setLayoutMode(monocle)

        // Only the surviving screen is written to. Setting a mode
        // on a space whose display just went away is a write
        // nobody asked for.
        #expect(applied.compactMap { $0 } == [SpaceID("1")])
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
