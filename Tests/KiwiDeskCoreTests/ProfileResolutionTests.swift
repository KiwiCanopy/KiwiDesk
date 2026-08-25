import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-core-\(UUID().uuidString)"
            )
    )
}

/// A core whose config is GUI-managed (a `gui.json` sidecar
/// exists) — the mode in which the built-in Standard may own
/// tiling when nothing matches (#53).
@MainActor
private func makeGuiManagedCore() -> KiwiCore {
    let core = makeCore()
    try? core.guiConfigStore.save(GuiConfig())
    return core
}

@MainActor
private func connect(
    _ core: KiwiCore,
    _ displays: [Display]
) {
    for display in displays {
        core.state.workspaces.upsertDisplay(display)
    }
}

/// A display named `name` with a 100x100 frame, so its
/// fingerprint is `"<name>:100x100"`.
private func display(
    _ id: UInt32,
    _ name: String,
    x: CGFloat = 0
) -> Display {
    Display(
        id: DisplayID(id),
        name: name,
        frame: CGRect(x: x, y: 0, width: 100, height: 100)
    )
}

@Suite("Monitor change matching", .serialized)
@MainActor
struct MonitorChangeTests {
    @Test("Exact set match adopts clean")
    func exactClean() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("desk")]
        )
        core.execute("load_profile", args: [.string("desk")])
        core.profiles.adoptStandard(named: "x")

        core.handleMonitorChange()
        #expect(core.profiles.currentName == "desk")
        #expect(!core.profiles.isDirty)
        #expect(core.profiles.currentStandard == nil)
    }

    @Test("Count default loads dirty on unknown monitors")
    func countDefaultDirty() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("known")]
        )
        core.state.workspaces.removeDisplay(DisplayID(1))
        connect(core, [display(2, "OTHER")])

        core.handleMonitorChange()
        #expect(core.profiles.currentName == "known")
        #expect(core.profiles.isDirty)
    }

    @Test("Exact re-dock of the active profile clears dirty")
    func redockClearsDirty() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("desk")]
        )
        // Undock onto unknown hardware of the same count: the
        // count's default profile loads dirty.
        core.state.workspaces.removeDisplay(DisplayID(1))
        connect(core, [display(2, "OTHER")])
        core.handleMonitorChange()
        #expect(core.profiles.isDirty)

        // Re-dock the original monitor: same profile, exact
        // set — the dirty flag must clear.
        core.state.workspaces.removeDisplay(DisplayID(2))
        connect(core, [display(1, "A")])
        core.handleMonitorChange()
        #expect(core.profiles.currentName == "desk")
        #expect(!core.profiles.isDirty)
    }

    @Test("No profile composes the built-in Standard")
    func standardFallback() throws {
        let core = makeGuiManagedCore()
        connect(core, [display(1, "A")])

        core.handleMonitorChange()
        #expect(core.profiles.currentName == nil)
        #expect(core.profiles.currentStandard == "Developer")
        #expect(core.profiles.isDirty)
        // The Developer Standard: 4 spaces, stack on 2.
        #expect(
            core.state.workspaces[SpaceID(2)]?.mode == .stack
        )
        #expect(
            core.tiler.settings.gapsGlobal == .uniform(8)
        )
        #expect(
            core.state.workspaces.display(of: SpaceID(1))
                == DisplayID(1)
        )
    }

    @Test("Without gui.json the Standard only steers placement")
    func luaOwnedTilingSurvives() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute("set_gap_global", args: [.number(30)])
        core.state.workspaces.ensureSpace(SpaceID(1))

        core.handleMonitorChange()
        // No transient-standard state, no dirty banner, and
        // the Lua-declared tiling is untouched (#36 promise).
        #expect(core.profiles.currentStandard == nil)
        #expect(!core.profiles.isDirty)
        #expect(
            core.tiler.settings.gapsGlobal == .uniform(30)
        )
        // Placement still resolves totally.
        #expect(
            core.state.workspaces.display(of: SpaceID(1))
                == DisplayID(1)
        )
    }

    // GUI-ownership coexistence tests (#14) live in
    // GuiOwnershipTests.swift (token-scoped detection).

    @Test("CLI-only: active profile goes dirty on no match")
    func luaOwnedActiveProfileGoesDirty() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("desk")]
        )
        // A second screen appears; no 2-screen profile exists
        // and there is no gui.json (CLI-only user): placement
        // recomposes, the profile keeps owning tiling, but the
        // state must report dirty — no stored set covers the
        // live monitors.
        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()
        #expect(core.profiles.currentName == "desk")
        #expect(core.profiles.currentStandard == nil)
        #expect(core.profiles.isDirty)
    }

    @Test("A native-space binding beats matching")
    func bindingWins() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.execute(
            "save_profile",
            args: [.string("Desk One")]
        )
        core.execute(
            "save_profile",
            args: [.string("Desk Two")]
        )
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(2), .string("Desk Two")]
        )
        NativeSpaces.activeDesktopNumberOverride = 2
        defer {
            NativeSpaces.activeDesktopNumberOverride = nil
        }

        core.handleMonitorChange()
        #expect(core.profiles.currentName == "Desk Two")
    }
}

@Suite("Space placement resolution", .serialized)
@MainActor
struct SpacePlacementTests {
    @Test("Pin beats Main beats positional default")
    func precedence() throws {
        let core = makeCore()
        let left = display(1, "L")
        let right = display(2, "R", x: 100)
        connect(core, [left, right])
        for number in 1...8 {
            core.state.workspaces.ensureSpace(SpaceID(number))
        }
        // Pin space 1 to the right screen even though the
        // 2-screen Standard puts it on main; space 5 follows
        // Main explicitly; space 6 falls to the default (its
        // positional plan: second screen).
        core.spacePins = [SpaceID(1): "R:100x100"]
        core.mainSpaces = [SpaceID(5)]

        core.resolveSpaceDisplays(mainID: DisplayID(1))
        let workspaces = core.state.workspaces
        #expect(
            workspaces.display(of: SpaceID(1)) == DisplayID(2)
        )
        #expect(
            workspaces.display(of: SpaceID(5)) == DisplayID(1)
        )
        #expect(
            workspaces.display(of: SpaceID(6)) == DisplayID(2)
        )
        // Space 2: unpinned, per plan on main.
        #expect(
            workspaces.display(of: SpaceID(2)) == DisplayID(1)
        )
    }

    @Test("Spaces outside the plan land on main")
    func offPlanSpaces() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.state.workspaces.ensureSpace(SpaceID("mail"))

        core.resolveSpaceDisplays(mainID: DisplayID(1))
        #expect(
            core.state.workspaces.display(of: SpaceID("mail"))
                == DisplayID(1)
        )
    }

    @Test("Explicit load prunes spaces the profile omits")
    func sparseProfilePrunesUndeclared() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        core.state.workspaces.ensureSpace(SpaceID(1))
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.setMode(SpaceID(2), .grid)
        try core.profiles.save(
            Profile(
                name: "sparse",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: ["1": .stack],
                settings: TilingSettings()
            )
        )
        core.execute(
            "load_profile",
            args: [.string("sparse")]
        )
        let workspaces = core.state.workspaces
        #expect(workspaces[SpaceID(1)]?.mode == .stack)
        // Undeclared by the (hand-edited, sparse) profile, so the
        // explicit load drops it — no stale grid mode lingers.
        #expect(workspaces[SpaceID(2)] == nil)
    }

    @Test("Loading a profile adopts its live set's pins")
    func applyAdoptsPins() throws {
        let core = makeCore()
        let a = display(1, "A")
        let b = display(2, "B", x: 100)
        connect(core, [a, b])
        core.state.workspaces.ensureSpace(SpaceID(1))
        try core.profiles.save(
            Profile(
                name: "pinned",
                monitorSets: [
                    MonitorSet(
                        monitors: [
                            "A:100x100", "B:100x100",
                        ],
                        spaceMonitorMap: [
                            SpaceID(1): "B:100x100"
                        ]
                    )
                ],
                mainSpaces: [SpaceID(2)],
                spaceModes: ["1": .stack, "2": .bsp],
                settings: TilingSettings()
            )
        )
        core.execute(
            "load_profile",
            args: [.string("pinned")]
        )
        #expect(core.spacePins == [SpaceID(1): "B:100x100"])
        #expect(core.mainSpaces == [SpaceID(2)])
        #expect(
            core.state.workspaces.display(of: SpaceID(1))
                == DisplayID(2)
        )
    }
}
