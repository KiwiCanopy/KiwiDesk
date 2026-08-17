import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Fake menu-bar slot so this suite never registers a real system
/// status item (#565 seam class). Per-file stub by convention.
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = nil
    var menu: NSMenu?
}

/// What a Layout row **applies** when it is fired, and when the
/// menu is allowed to claim drift (#752).
///
/// Both halves exist because a `guard-prover` run found them
/// unguarded (2026-08-17), and the first is the feature's headline
/// behaviour: the sibling suites prove a screen's rows *carry* the
/// right space, and nothing fired one to see whether the handler
/// honoured it. `setLayoutMode`'s `.space(id)` arm could be
/// replaced with `nil` — every per-screen pick silently retiling
/// the focused space — with the whole suite green.
///
/// `@MainActor` for `NSMenu`, and that is all it spends there.
/// `.serialized` because titles are matched in English through the
/// process-wide `LocalizationManager`.
@Suite("Layout quick menu dispatch and drift (#752)", .serialized)
@MainActor
struct LayoutMenuDispatchTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        return core
    }

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

    private func modeRow(
        _ menu: NSMenu,
        _ mode: LayoutMode
    ) throws -> NSMenuItem {
        try #require(
            menu.items.first {
                ($0.representedObject as? LayoutMenuTarget)?.mode
                    == mode
            }
        )
    }

    // MARK: - What a row applies

    @Test("A screen's row applies to THAT screen's space")
    func screenRowAppliesToItsOwnSpace() throws {
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
        var applied: [(mode: LayoutMode, space: SpaceID?)] = []
        controller.onSetLayoutMode = { applied.append(($0, $1)) }
        let submenu = try #require(controller.layoutItem().submenu)
        let right = try #require(
            submenu.items.first { $0.title == "Right" }?.submenu
        )

        controller.setLayoutMode(try modeRow(right, .monocle))

        // ONE apply, naming space 7 — not the active space (1),
        // which is what a `nil` would have meant and what the
        // carrying assertions in the sibling suite cannot see.
        #expect(applied.count == 1)
        #expect(applied.first?.mode == .monocle)
        #expect(applied.first?.space == SpaceID("7"))
    }

    @Test("A flat-menu row applies to the active space")
    func flatRowAppliesToActiveSpace() throws {
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
        var applied: [(mode: LayoutMode, space: SpaceID?)] = []
        controller.onSetLayoutMode = { applied.append(($0, $1)) }
        let submenu = try #require(controller.layoutItem().submenu)

        controller.setLayoutMode(try modeRow(submenu, .grid))

        // nil, deliberately: the one-argument `set_mode` is what
        // the flat menu has always issued, and a row that started
        // naming a space here would change behaviour nobody asked
        // to change.
        #expect(applied.count == 1)
        #expect(applied.first?.mode == .grid)
        #expect(applied.first?.space == nil)
    }

    @Test("A row carrying no target applies nothing")
    func unrecognisedRowIsInert() {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        let controller = makeController(core)
        var applied = 0
        controller.onSetLayoutMode = { _, _ in applied += 1 }

        // A menu item from anywhere else in the app, handed to the
        // selector: the guard clause is the only thing between it
        // and a mode change on the focused space.
        controller.setLayoutMode(NSMenuItem())

        #expect(applied == 0)
    }

    // MARK: - When drift may be claimed

    @Test("Drift needs the saved mode to be KNOWN")
    func driftNeedsAKnownSavedMode() {
        // nil saved is "no profile, or JSON that would not
        // decode" — unknown, never "differs". Claiming drift there
        // puts a "not saved to profile" subtitle on a space that
        // has nothing to be unsaved against.
        #expect(!LayoutMenuInfo.drifted(live: .bsp, saved: nil))
        #expect(!LayoutMenuInfo.drifted(live: nil, saved: .bsp))
        #expect(!LayoutMenuInfo.drifted(live: nil, saved: nil))
        // And it is still drift when both are known and differ.
        #expect(LayoutMenuInfo.drifted(live: .bsp, saved: .grid))
        #expect(!LayoutMenuInfo.drifted(live: .grid, saved: .grid))
    }

    @Test("A screen with no readable profile claims no drift")
    func screenWithoutProfileClaimsNoDrift() {
        let screen = LayoutMenuInfo.Screen(
            space: SpaceID("1"),
            name: "Left",
            id: DisplayID(1),
            origin: .zero,
            mode: .monocle,
            savedMode: nil
        )
        #expect(!screen.hasDrifted)
        #expect(
            LayoutMenuInfo.Screen(
                space: SpaceID("1"),
                name: "Left",
                id: DisplayID(1),
                origin: .zero,
                mode: .monocle,
                savedMode: .bsp
            ).hasDrifted
        )
    }

    @Test("No profile means no subtitle on any screen row")
    func noProfileDrawsNoSubtitle() throws {
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
        // No profile loaded, so every `savedMode` is nil.
        #expect(core.profiles.currentName == nil)
        let controller = makeController(core)
        let submenu = try #require(controller.layoutItem().submenu)

        // The rendered consequence of the rule above: a phantom
        // subtitle is what a reader would actually meet.
        guard #available(macOS 14.4, *) else { return }
        for parent in submenu.items where parent.submenu != nil {
            for row in try #require(parent.submenu).items {
                #expect(row.subtitle == nil)
            }
        }
    }
}
