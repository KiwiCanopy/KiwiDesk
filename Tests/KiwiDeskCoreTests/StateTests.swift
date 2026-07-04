import CoreGraphics
import Testing

@testable import KiwiDeskCore

private func makeWindow(
    _ id: UInt32,
    pid: pid_t = 100,
    app: String = "TestApp"
) -> ManagedWindow {
    ManagedWindow(id: WindowID(id), pid: pid, appName: app)
}

@Suite("WindowManager")
struct WindowManagerTests {
    @Test("Upsert and remove")
    func upsertRemove() {
        var manager = WindowManager()
        manager.upsert(makeWindow(1))
        manager.upsert(makeWindow(2))
        #expect(manager.count == 2)
        #expect(manager[WindowID(1)] != nil)
        manager.remove(WindowID(1))
        #expect(manager[WindowID(1)] == nil)
        #expect(manager.count == 1)
    }

    @Test("RemoveAll drops every window of a pid")
    func removeAllByPid() {
        var manager = WindowManager()
        manager.upsert(makeWindow(1, pid: 100))
        manager.upsert(makeWindow(2, pid: 100))
        manager.upsert(makeWindow(3, pid: 200))
        let removed = manager.removeAll(pid: 100)
        #expect(Set(removed) == [WindowID(1), WindowID(2)])
        #expect(manager.count == 1)
    }

    @Test("Frame and title updates")
    func updates() {
        var manager = WindowManager()
        manager.upsert(makeWindow(1))
        let frame = CGRect(x: 10, y: 20, width: 30, height: 40)
        manager.updateFrame(WindowID(1), frame: frame)
        manager.updateTitle(WindowID(1), title: "Hello")
        #expect(manager[WindowID(1)]?.frame == frame)
        #expect(manager[WindowID(1)]?.title == "Hello")
    }
}

@Suite("WorkspaceManager")
struct WorkspaceManagerTests {
    @Test("First space becomes active")
    func firstSpaceActive() {
        var manager = WorkspaceManager()
        manager.ensureSpace("code")
        manager.ensureSpace("mail")
        #expect(manager.activeSpace == SpaceID("code"))
    }

    @Test("A window lives in at most one space")
    func singleMembership() {
        var manager = WorkspaceManager()
        let w = WindowID(1)
        manager.add(w, to: "code")
        manager.add(w, to: "mail")
        #expect(manager.space(of: w) == SpaceID("mail"))
        #expect(manager["code"]?.windows.isEmpty == true)
    }

    @Test("Display assignment and removal")
    func displayAssignment() {
        var manager = WorkspaceManager()
        let display = Display(
            id: DisplayID(1),
            name: "LG",
            frame: .zero
        )
        manager.upsertDisplay(display)
        manager.assign("code", to: display.id)
        #expect(manager.display(of: "code") == display.id)
        #expect(manager.spaces(on: display.id) == ["code"])
        manager.removeDisplay(display.id)
        #expect(manager.display(of: "code") == nil)
    }
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
        state.apply(.windowDestroyed(WindowID(1)))
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
        // Native desktop switch / minimize: window vanishes
        // from AX and is destroyed, then comes back later.
        state.apply(.windowDestroyed(WindowID(1)))
        state.apply(.windowCreated(makeWindow(1)))
        #expect(
            state.workspaces.space(of: WindowID(1))
                == SpaceID("mail")
        )
    }

    @Test("Remembered space beats app rules")
    func rememberedBeatsAppRules() {
        var state = StateCoordinator()
        state.appRules = ["TestApp": SpaceID("music")]
        state.apply(.windowCreated(makeWindow(1)))
        state.workspaces.add(WindowID(1), to: SpaceID("code"))
        state.apply(.windowDestroyed(WindowID(1)))
        state.apply(.windowCreated(makeWindow(1)))
        #expect(
            state.workspaces.space(of: WindowID(1))
                == SpaceID("code")
        )
    }
}
