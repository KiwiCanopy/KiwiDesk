import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The list grows to a third of the screen's visible height, never
/// fewer than 6 rows nor more than 12, and shrinks to fit fewer
/// results (#1875 ▸ Panel). A pick distrusts the dismiss blip, and
/// a refused Move here hands activation back (#952).
@Suite("Jump to window panel controller")
@MainActor
struct JumpPanelControllerTests {
    @Test("the row cap is a third of the screen, 6 to 12 rows")
    func rowCap() {
        let row = JumpRowView.height
        #expect(JumpPanelController.rowCap(visibleHeight: 300) == 6)
        #expect(
            JumpPanelController.rowCap(visibleHeight: 3 * row * 8) == 8
        )
        #expect(JumpPanelController.rowCap(visibleHeight: 5000) == 12)
    }

    @Test("the list fits its rows up to the cap")
    func listHeight() {
        let row = JumpRowView.height
        let pad = 2 * JumpPanelView.listPadding
        #expect(
            JumpPanelView.listHeight(rows: 2, hasHeader: false, rowCap: 6)
                == 2 * row + pad
        )
        #expect(
            JumpPanelView.listHeight(rows: 2, hasHeader: true, rowCap: 6)
                == 2 * row + JumpPanelView.headerHeight + pad
        )
        #expect(
            JumpPanelView.listHeight(rows: 40, hasHeader: true, rowCap: 6)
                == 6 * row + pad
        )
    }

    @Test("a pick distrusts the dismiss blip unless it is our own")
    func pickHandoff() {
        #expect(JumpPanelController.distrustsHandoff(pick: 42, own: 7))
        #expect(!JumpPanelController.distrustsHandoff(pick: 7, own: 7))
    }

    private func controller() -> (JumpPanelController, KiwiCore) {
        let core = makeTestCore()
        for space in ["1", "2"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        var window = ManagedWindow(
            id: WindowID(9),
            pid: 4242,
            appName: "Notes",
            appBundleID: "app.test.notes"
        )
        window.isFullscreen = true
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(9), to: "2")
        let controller = JumpPanelController(core: core)
        controller.handBack.isAppActive = { true }
        return (controller, core)
    }

    private func entry(pid: pid_t = 4242) -> JumpEntry {
        JumpEntry(
            target: .window(WindowID(9)),
            pid: pid,
            app: "Notes",
            title: "",
            space: "2",
            spaceIcon: nil,
            status: .fullscreen
        )
    }

    @Test("a refused Move here hands activation back")
    func refusedMoveHereYields() {
        let (controller, core) = controller()
        let target = NSRunningApplication.current
        controller.handBack.returnTarget = target
        var yielded: [NSRunningApplication] = []
        controller.handBack.activateReturnTarget = { yielded.append($0) }
        controller.pick(entry(), moveHere: true)
        #expect(
            yielded.map(\.processIdentifier) == [
                target.processIdentifier
            ]
        )
        // The pick's dismiss armed the distrust for our own pid.
        #expect(
            core.ignoredPanel.active.contains(
                pid_t(ProcessInfo.processInfo.processIdentifier)
            )
        )
        #expect(controller.handBack.returnTarget == nil)
    }

    @Test("a Jump never hands activation back")
    func jumpDoesNotYield() {
        let (controller, _) = controller()
        controller.handBack.returnTarget = NSRunningApplication.current
        var yielded = 0
        controller.handBack.activateReturnTarget = { _ in yielded += 1 }
        controller.pick(entry(), moveHere: false)
        #expect(yielded == 0)
    }

    @Test("a pick of our own window arms no distrust")
    func ownPickArmsNothing() {
        let (controller, core) = controller()
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        controller.pick(entry(pid: own), moveHere: false)
        #expect(core.ignoredPanel.active.isEmpty)
    }

    @Test("Esc's close yields; a click away does not")
    func closeYields() {
        let (controller, _) = controller()
        var yielded = 0
        controller.handBack.activateReturnTarget = { _ in yielded += 1 }
        controller.handBack.returnTarget = NSRunningApplication.current
        controller.close(yieldingActivation: false)
        #expect(yielded == 0)
        controller.handBack.returnTarget = NSRunningApplication.current
        controller.close(yieldingActivation: true)
        #expect(yielded == 1)
    }

    @Test("a close of an already hidden panel does nothing")
    func hiddenPanelCloseIsInert() {
        let (controller, core) = controller()
        controller.panel = controller.makePanel()
        controller.handBack.returnTarget = NSRunningApplication.current
        var yielded = 0
        controller.handBack.activateReturnTarget = { _ in yielded += 1 }
        controller.close(yieldingActivation: true)
        #expect(yielded == 0)
        #expect(controller.handBack.returnTarget != nil)
        #expect(core.ignoredPanel.active.isEmpty)
    }

    @Test("deactivation never hides the panel behind the close")
    func deactivationDoesNotHide() {
        let (controller, _) = controller()
        #expect(!controller.makePanel().hidesOnDeactivate)
    }
}
