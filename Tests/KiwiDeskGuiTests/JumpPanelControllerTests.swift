import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The list holds nine rows of room under the panel's one ceiling
/// (#2309), and shrinks to fit fewer results (#1875 ▸ Panel). A
/// pick of another app's window distrusts the dismiss blip (#952);
/// a close arms nothing.
@Suite("Jump to window panel controller")
@MainActor
struct JumpPanelControllerTests {
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

    /// Spotlight's height rather than the screen's middle (owner
    /// eyeball, 2026-10-13): the top sits a quarter down and stays
    /// there for every panel height that fits.
    @Test("the panel's top sits at Spotlight's height")
    func origin() {
        let visible = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let top: CGFloat =
            visible.maxY - visible.height
            * JumpPanelController.topFraction
        for height: CGFloat in [200, 400] {
            let size = CGSize(width: 640, height: height)
            let origin = JumpPanelController.origin(
                size: size,
                visible: visible
            )
            #expect(origin.x == 480)
            #expect(origin.y + height == top)
        }
        // A panel taller than the room below that top is lifted
        // rather than run off the screen.
        let tall = JumpPanelController.origin(
            size: CGSize(width: 640, height: 900),
            visible: visible
        )
        #expect(tall.y == visible.minY)
    }

    /// A scope's own shortcut (#2229): closes where it shows,
    /// switches from the other, opens where nothing shows.
    @Test("a scope's shortcut opens, switches or closes")
    func toggleAction() {
        typealias C = JumpPanelController
        #expect(C.toggleAction(showing: nil, asked: .view) == .open)
        #expect(
            C.toggleAction(showing: .windows, asked: .view)
                == .switchScope
        )
        #expect(
            C.toggleAction(showing: .view, asked: .view) == .close
        )
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

    /// The window a close keys again is the one the user was in,
    /// so its report is honored (owner ruling 2026-10-13).
    @Test("a close arms no distrust, even with KiwiDesk active")
    func closeArmsNothing() {
        let (controller, core) = controller()
        controller.handBack.isAppActive = { true }
        controller.close()
        #expect(core.ignoredPanel.active.isEmpty)
    }

    /// A panel already hidden has no blip to distrust: the same
    /// pick `pickArmsTheDistrust` arms on stands down here.
    @Test("a pick on a hidden panel arms nothing")
    func hiddenPanelPickIsInert() {
        let (controller, core) = controller()
        controller.panel = controller.makePanel()
        #expect(controller.panel?.isVisible == false)
        controller.pick(entry(), moveHere: true)
        #expect(core.ignoredPanel.active.isEmpty)
    }

    @Test("deactivation never hides the panel behind the close")
    func deactivationDoesNotHide() {
        let (controller, _) = controller()
        #expect(!controller.makePanel().hidesOnDeactivate)
    }
}
