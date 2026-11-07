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

@Suite("WindowManager")
struct WindowManagerTests {
    @Test("Upsert and remove")
    func upsertRemove() {
        var manager = WindowManager()
        manager.upsert(makeWindow(1))
        manager.upsert(makeWindow(2))
        expectEqual(manager.count, 2)
        #expect(manager[WindowID(1)] != nil)
        manager.remove(WindowID(1))
        #expect(manager[WindowID(1)] == nil)
        expectEqual(manager.count, 1)
    }

    @Test("RemoveAll drops every window of a pid")
    func removeAllByPid() {
        var manager = WindowManager()
        manager.upsert(makeWindow(1, pid: 100))
        manager.upsert(makeWindow(2, pid: 100))
        manager.upsert(makeWindow(3, pid: 200))
        let removed = manager.removeAll(pid: 100)
        expectEqual(Set(removed), [WindowID(1), WindowID(2)])
        expectEqual(manager.count, 1)
    }

    @Test("Frame and title updates")
    func updates() {
        var manager = WindowManager()
        manager.upsert(makeWindow(1))
        let frame = CGRect(x: 10, y: 20, width: 30, height: 40)
        manager.updateFrame(WindowID(1), frame: frame)
        manager.updateTitle(WindowID(1), title: "Hello")
        expectEqual(manager[WindowID(1)]?.frame, frame)
        expectEqual(manager[WindowID(1)]?.title, "Hello")
    }
}

@Suite("WorkspaceManager")
struct WorkspaceManagerTests {
    @Test("First space becomes active")
    func firstSpaceActive() {
        var manager = WorkspaceManager()
        manager.ensureSpace("code")
        manager.ensureSpace("mail")
        expectEqual(manager.activeSpace, SpaceID("code"))
    }

    @Test("A window lives in at most one space")
    func singleMembership() {
        var manager = WorkspaceManager()
        let w = WindowID(1)
        manager.add(w, to: "code")
        manager.add(w, to: "mail")
        expectEqual(manager.space(of: w), SpaceID("mail"))
        expectEqual(manager["code"]?.windows.isEmpty, true)
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
        expectEqual(manager.display(of: "code"), display.id)
        expectEqual(manager.spaces(on: display.id), ["code"])
        manager.removeDisplay(display.id)
        #expect(manager.display(of: "code") == nil)
    }

    @Test("currentSpace prefers the active space on a display")
    func currentSpaceActive() {
        var manager = WorkspaceManager()
        let main = DisplayID(1)
        let side = DisplayID(2)
        // "web" first on side, then two on main; "main2" active.
        manager.assign("web", to: side)
        manager.assign("main1", to: main)
        manager.assign("main2", to: main)
        manager.activate("main2")
        // The active space wins on its own display; the other
        // display shows its first-assigned space.
        expectEqual(manager.currentSpace(on: main), "main2")
        expectEqual(manager.currentSpace(on: side), "web")
    }

    @Test("currentSpace falls back to the first assigned space")
    func currentSpaceFallback() {
        var manager = WorkspaceManager()
        let side = DisplayID(2)
        manager.assign("a", to: side)
        manager.assign("b", to: side)
        // Active space lives on another (untracked) display, so
        // the side display shows its first-assigned space.
        manager.assign("elsewhere", to: DisplayID(9))
        manager.activate("elsewhere")
        expectEqual(manager.currentSpace(on: side), "a")
        // No space assigned → nil.
        #expect(manager.currentSpace(on: DisplayID(3)) == nil)
    }
}
