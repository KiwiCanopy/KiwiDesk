import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The list grows to a third of the screen's visible height, never
/// fewer than 8 rows nor more than 10 (#2229), and shrinks to fit
/// fewer results (#1875 ▸ Panel). A pick of another app's window and a
/// commanded close distrust the dismiss blip (#952).
@Suite("Jump to window panel controller")
@MainActor
struct JumpPanelControllerTests {
    @Test("the row cap is a third of the screen, 8 to 10 rows")
    func rowCap() {
        let row = JumpRowView.height
        #expect(JumpPanelController.rowCap(visibleHeight: 300) == 8)
        #expect(
            JumpPanelController.rowCap(visibleHeight: 3 * row * 9) == 9
        )
        #expect(JumpPanelController.rowCap(visibleHeight: 5000) == 10)
    }

    /// The footer's scroll cue shows exactly when the content runs
    /// past the cap — headers included.
    @Test("the list overflows only past the cap")
    func overflow() {
        #expect(!JumpPanelView.overflows(rows: 6, headers: 0, rowCap: 6))
        #expect(JumpPanelView.overflows(rows: 7, headers: 0, rowCap: 6))
        #expect(JumpPanelView.overflows(rows: 6, headers: 1, rowCap: 6))
    }

    @Test("the panel keeps its width, narrowed on a small screen")
    func width() {
        let full = JumpPanelView.width
        #expect(JumpPanelController.width(visibleWidth: 3000) == full)
        // A narrow screen keeps the panel clear of both edges.
        let narrow = JumpPanelController.width(visibleWidth: 600)
        #expect(narrow < 600 && narrow < full)
    }

    @Test("the list fits its rows up to the cap")
    func listHeight() {
        let row = JumpRowView.height
        let pad = 2 * JumpPanelView.listPadding
        #expect(
            JumpPanelView.listHeight(rows: 2, headers: 0, rowCap: 6)
                == 2 * row + pad
        )
        #expect(
            JumpPanelView.listHeight(rows: 2, headers: 2, rowCap: 6)
                == 2 * row + 2 * JumpPanelView.headerHeight + pad
        )
        #expect(
            JumpPanelView.listHeight(rows: 40, headers: 1, rowCap: 6)
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

    @Test("a pick arms the dismiss distrust for another app's window")
    func pickArmsTheDistrust() {
        let (controller, core) = controller()
        controller.handBack.isAppActive = { true }
        controller.pick(entry(), moveHere: true)
        #expect(
            core.ignoredPanel.active.contains(
                pid_t(ProcessInfo.processInfo.processIdentifier)
            )
        )
    }

    @Test("a pick of our own window arms no distrust")
    func ownPickArmsNothing() {
        let (controller, core) = controller()
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        controller.pick(entry(pid: own), moveHere: false)
        #expect(core.ignoredPanel.active.isEmpty)
    }

    @Test("Esc's close arms the distrust; a click away does not")
    func closeDistrusts() {
        // One close per opening: the fade's own guard refuses a
        // second, so each close takes a controller of its own.
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        let (away, awayCore) = controller()
        away.handBack.isAppActive = { true }
        away.close(commanded: false)
        #expect(awayCore.ignoredPanel.active.isEmpty)
        let (esc, escCore) = controller()
        esc.handBack.isAppActive = { true }
        esc.close(commanded: true)
        #expect(escCore.ignoredPanel.active.contains(own))
    }

    @Test("a close of an already hidden panel does nothing")
    func hiddenPanelCloseIsInert() {
        let (controller, core) = controller()
        controller.panel = controller.makePanel()
        controller.handBack.isAppActive = { true }
        controller.close(commanded: true)
        #expect(core.ignoredPanel.active.isEmpty)
    }

    @Test("deactivation never hides the panel behind the close")
    func deactivationDoesNotHide() {
        let (controller, _) = controller()
        #expect(!controller.makePanel().hidesOnDeactivate)
    }
}
