import CoreGraphics
import Testing

@testable import KiwiDeskCore

private func makeWindow(
    _ id: UInt32,
    pid: pid_t = 100,
    app: String = "TestApp",
    bundleID: String? = nil
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: pid,
        appName: app,
        appBundleID: bundleID
    )
}

@Suite("StateCoordinator")
struct StateCoordinatorTests {
    @Test("Window creation adds to active space and focuses")
    func windowCreated() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        #expect(state.windows.count == 1)
        let space = state.workspaces[SpaceID(1)]
        #expect(space?.windows == [WindowID(1)])
        #expect(space?.focused == WindowID(1))
    }

    @Test("Window destruction cleans both managers")
    func windowDestroyed() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        #expect(state.windows.count == 0)
        #expect(
            state.workspaces[SpaceID(1)]?.windows.isEmpty
                == true
        )
    }

    @Test("Float re-check heals a misclassified window")
    func floatChanged() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        #expect(
            state.windows[WindowID(1)]?.isFloating == false
        )
        state.apply(
            .windowFloatChanged(WindowID(1), isFloating: true)
        )
        #expect(
            state.windows[WindowID(1)]?.isFloating == true
        )
        // Space membership is untouched: floating windows
        // stay in the space array, layouts filter them.
        #expect(
            state.workspaces[SpaceID(1)]?.windows
                == [WindowID(1)]
        )
    }

    @Test("App termination removes all its windows")
    func appTerminated() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1, pid: 100)))
        state.apply(.windowCreated(makeWindow(2, pid: 100)))
        state.apply(.windowCreated(makeWindow(3, pid: 200)))
        state.apply(.appTerminated(pid: 100))
        #expect(state.windows.count == 1)
        #expect(
            state.workspaces[SpaceID(1)]?.windows
                == [WindowID(3)]
        )
    }

    @Test("Display changes are reconciled")
    func displaysReconciled() {
        var state = StateCoordinator()
        let a = Display(id: DisplayID(1), name: "A", frame: .zero)
        let b = Display(id: DisplayID(2), name: "B", frame: .zero)
        state.apply(.displaysChanged([a, b]))
        #expect(state.workspaces.allDisplays.count == 2)
        state.apply(.displaysChanged([b]))
        #expect(state.workspaces.allDisplays.count == 1)
        #expect(
            state.workspaces.allDisplays.first?.id
                == DisplayID(2)
        )
    }

    @Test("New windows split the focused window's region")
    func insertAfterFocused() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.apply(.windowCreated(makeWindow(2)))
        state.apply(.windowCreated(makeWindow(3)))
        // Focus back to window 1, then open window 4: it
        // must land right after window 1, not at the end.
        state.apply(.windowFocused(WindowID(1)))
        state.apply(.windowCreated(makeWindow(4)))
        #expect(
            state.workspaces[SpaceID(1)]?.windows == [
                WindowID(1), WindowID(4),
                WindowID(2), WindowID(3),
            ]
        )
    }

    @Test("Stack mode spawns new windows as master (first)")
    func stackSpawnsFirstByDefault() {
        var state = StateCoordinator()
        state.workspaces.setMode(SpaceID(1), .stack)
        state.apply(.windowCreated(makeWindow(1)))
        state.apply(.windowCreated(makeWindow(2)))
        state.apply(.windowCreated(makeWindow(3)))
        #expect(
            state.workspaces[SpaceID(1)]?.windows == [
                WindowID(3), WindowID(2), WindowID(1),
            ]
        )
    }

    @Test("Spawn placement 'last' appends to the end")
    func spawnPlacementLast() {
        var state = StateCoordinator()
        state.workspaces.setMode(SpaceID(1), .stack)
        state.spawnPlacements[.stack] = .last
        state.apply(.windowCreated(makeWindow(1)))
        state.apply(.windowCreated(makeWindow(2)))
        state.apply(.windowCreated(makeWindow(3)))
        // Focus back to window 1: the new window must not
        // land next to it but at the very end.
        state.apply(.windowFocused(WindowID(1)))
        state.apply(.windowCreated(makeWindow(4)))
        #expect(
            state.workspaces[SpaceID(1)]?.windows == [
                WindowID(1), WindowID(2),
                WindowID(3), WindowID(4),
            ]
        )
    }

    @Test("Spawn placement 'before_focused' inserts left")
    func spawnPlacementBeforeFocused() {
        var state = StateCoordinator()
        state.spawnPlacements[.bsp] = .beforeFocused
        // Every new window takes focus, so window 2 lands
        // before 1; window 3 before the re-focused 1.
        state.apply(.windowCreated(makeWindow(1)))
        state.apply(.windowCreated(makeWindow(2)))
        state.apply(.windowFocused(WindowID(1)))
        state.apply(.windowCreated(makeWindow(3)))
        #expect(
            state.workspaces[SpaceID(1)]?.windows == [
                WindowID(2), WindowID(3), WindowID(1),
            ]
        )
    }

    @Test("Per-space override beats the layout placement")
    func spawnOverrideWins() {
        var state = StateCoordinator()
        state.workspaces.setMode(SpaceID(1), .stack)
        state.spawnOverride[SpaceID(1)] = .last
        state.apply(.windowCreated(makeWindow(1)))
        state.apply(.windowCreated(makeWindow(2)))
        state.apply(.windowCreated(makeWindow(3)))
        #expect(
            state.workspaces[SpaceID(1)]?.windows == [
                WindowID(1), WindowID(2), WindowID(3),
            ]
        )
    }

    @Test("Focus event updates the containing space")
    func focusTracking() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.apply(.windowCreated(makeWindow(2)))
        state.apply(.windowFocused(WindowID(1)))
        #expect(
            state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
    }

    @Test("Reappearing windows return to their old space")
    func remembersSpace() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.workspaces.add(WindowID(1), to: SpaceID("mail"))
        // Native desktop switch: window vanishes from AX and
        // is destroyed, then comes back later.
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(1)))
        #expect(
            state.workspaces.space(of: WindowID(1))
                == SpaceID("mail")
        )
    }

    @Test("App rule routes a new window by bundle id")
    func appRuleRoutesByBundleID() {
        var state = StateCoordinator()
        state.appRules = ["com.apple.mail": SpaceID("mail")]
        state.apply(
            .windowCreated(
                makeWindow(1, bundleID: "com.apple.mail")
            )
        )
        #expect(
            state.workspaces.space(of: WindowID(1))
                == SpaceID("mail")
        )
    }

    @Test("App rule keys on bundle id, not display name")
    func appRuleIgnoresDisplayName() {
        var state = StateCoordinator()
        // Rule keyed by bundle id. A window whose display name
        // would have matched the old scheme but whose bundle id
        // differs must NOT route — the whole point of the fix.
        state.appRules = ["com.apple.mail": SpaceID("music")]
        state.apply(
            .windowCreated(
                makeWindow(
                    1,
                    app: "Mail",
                    bundleID: "com.example.other"
                )
            )
        )
        #expect(
            state.workspaces.space(of: WindowID(1))
                != SpaceID("music")
        )
    }

    @Test("Remembered space beats app rules")
    func rememberedBeatsAppRules() {
        var state = StateCoordinator()
        state.appRules = ["com.apple.mail": SpaceID("music")]
        state.apply(
            .windowCreated(
                makeWindow(1, bundleID: "com.apple.mail")
            )
        )
        state.workspaces.add(WindowID(1), to: SpaceID("code"))
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(
            .windowCreated(
                makeWindow(1, bundleID: "com.apple.mail")
            )
        )
        #expect(
            state.workspaces.space(of: WindowID(1))
                == SpaceID("code")
        )
    }

    @Test("Deminiaturized windows open in the active space")
    func minimizeForgetsSpace() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.workspaces.add(WindowID(1), to: SpaceID("mail"))
        // Minimize forgets the space, so restoring from the
        // Dock lands in whatever space is active by then.
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: true)
        )
        state.workspaces.activate(SpaceID("code"))
        state.apply(.windowCreated(makeWindow(1)))
        #expect(
            state.workspaces.space(of: WindowID(1))
                == SpaceID("code")
        )
    }

    @Test("Minimize clears a space remembered earlier")
    func minimizeClearsStaleMemory() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.workspaces.add(WindowID(1), to: SpaceID("mail"))
        // Native desktop round-trip stores a memory...
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(1)))
        // ...which a later minimize must invalidate.
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: true)
        )
        state.workspaces.activate(SpaceID("code"))
        state.apply(.windowCreated(makeWindow(1)))
        #expect(
            state.workspaces.space(of: WindowID(1))
                == SpaceID("code")
        )
    }
}
