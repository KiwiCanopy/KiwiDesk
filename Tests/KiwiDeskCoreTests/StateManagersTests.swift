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
        #expect(manager.currentSpace(on: main) == "main2")
        #expect(manager.currentSpace(on: side) == "web")
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
        #expect(manager.currentSpace(on: side) == "a")
        // No space assigned → nil.
        #expect(manager.currentSpace(on: DisplayID(3)) == nil)
    }

    @Test(
        """
        A cross-display drop lands on the target's index, \
        shifting the target down and dropping from the origin \
        (#492)
        """
    )
    func crossDisplayMoveInsert() {
        var manager = WorkspaceManager()
        manager.add(WindowID(1), to: "A")
        manager.add(WindowID(2), to: "A")
        manager.add(WindowID(3), to: "B")
        manager.add(WindowID(4), to: "B")
        // Drop window 1 (from A) onto window 4's slot in B — the
        // exact add-then-move `relocateAcrossDisplay` performs.
        let target = WindowID(4)
        let targetIndex =
            manager["B"]?.windows
            .firstIndex(of: target) ?? 0
        manager.add(WindowID(1), to: "B", after: target)
        manager.withSpace("B") { $0.move(WindowID(1), to: targetIndex) }
        // 1 takes 4's old index (1); 4 shifts to index 2.
        #expect(
            manager["B"]?.windows
                == [WindowID(3), WindowID(1), WindowID(4)]
        )
        // 1 is gone from the origin space.
        #expect(manager["A"]?.windows == [WindowID(2)])
        #expect(manager.space(of: WindowID(1)) == SpaceID("B"))
    }

    @Test("A cross-display drop onto the first slot inserts at 0")
    func crossDisplayMoveFirstSlot() {
        var manager = WorkspaceManager()
        manager.add(WindowID(1), to: "A")
        manager.add(WindowID(2), to: "B")
        manager.add(WindowID(3), to: "B")
        let target = WindowID(2)
        let targetIndex =
            manager["B"]?.windows
            .firstIndex(of: target) ?? 0
        manager.add(WindowID(1), to: "B", after: target)
        manager.withSpace("B") { $0.move(WindowID(1), to: targetIndex) }
        // 1 takes the head slot; 2 shifts to index 1.
        #expect(
            manager["B"]?.windows
                == [WindowID(1), WindowID(2), WindowID(3)]
        )
        #expect(manager["A"]?.windows.isEmpty == true)
    }

    @Test(
        """
        A cross-display drop over empty space appends to the \
        destination — the no-target path for an empty monitor \
        (#492)
        """
    )
    func crossDisplayMoveEmptyDestination() {
        var manager = WorkspaceManager()
        manager.add(WindowID(1), to: "A")
        manager.add(WindowID(2), to: "A")
        // Destination "B" has no windows (an empty monitor). With
        // no target, `relocateAcrossDisplay` appends via
        // `add(_:to:after:)` with a nil anchor.
        manager.add(WindowID(1), to: "B", after: nil)
        #expect(manager["B"]?.windows == [WindowID(1)])
        #expect(manager["A"]?.windows == [WindowID(2)])
        #expect(manager.space(of: WindowID(1)) == SpaceID("B"))
    }
}
