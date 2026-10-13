import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The key panels' exit fade (#1875): a panel fading out is no
/// longer open, a show a close or a later show overtook keys
/// nothing, and a pick during the fade runs nothing. The panels
/// are ordered in for real — `isOpen` reads `isVisible` — and
/// never keyed; each test orders its panel out again.
@Suite("Key panel fade guards (#1875)", .serialized)
@MainActor
struct PanelFadeGuardTests {
    /// Defers the order-front and records which panels it keyed,
    /// ordering them in unkeyed so `isVisible` reads true.
    @MainActor
    private final class Front {
        var deferred: [@MainActor () -> Void] = []
        var keyed: [NSWindow] = []

        func wire(_ handBack: PanelHandBack) {
            handBack.isAppActive = { true }
            handBack.nextTurn = { [unowned self] in
                deferred.append($0)
            }
            handBack.orderFrontKey = { [unowned self] in
                keyed.append($0)
                $0.orderFrontRegardless()
            }
        }

        func drain() {
            let work = deferred
            deferred = []
            work.forEach { $0() }
        }
    }

    private func jump() -> (JumpPanelController, Front) {
        let controller = JumpPanelController(core: makeTestCore())
        controller.reduceMotion = { true }
        let front = Front()
        front.wire(controller.handBack)
        return (controller, front)
    }

    @Test("a Jump panel fading out is no longer open")
    func jumpLeavingIsClosed() {
        let (controller, front) = jump()
        controller.show()
        front.drain()
        defer { front.keyed.forEach { $0.orderOut(nil) } }
        #expect(controller.isOpen)
        controller.close()
        #expect(controller.panel?.isVisible == true)
        #expect(!controller.isOpen)
    }

    @Test("a Jump show a later show overtook keys nothing")
    func jumpOvertakenShow() {
        let (controller, front) = jump()
        controller.show()
        let first = front.deferred
        front.deferred = []
        controller.show()
        defer { front.keyed.forEach { $0.orderOut(nil) } }
        first.forEach { $0() }
        #expect(front.keyed.isEmpty)
        front.drain()
        #expect(front.keyed.count == 1)
    }

    /// The panel is still up from the opening before, so the close
    /// in between starts a fade the deferred key must not undo.
    @Test("a Jump show closed before its turn keys nothing")
    func jumpClosedBeforeKey() {
        let (controller, front) = jump()
        controller.show()
        front.drain()
        defer { front.keyed.forEach { $0.orderOut(nil) } }
        controller.show()
        controller.close()
        front.drain()
        #expect(front.keyed.count == 1)
    }

    /// A core holding window 9 in Space 2 while Space 1 is shown.
    private func coreWithAwayWindow() -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for space: SpaceID in ["1", "2"] {
            core.state.workspaces.ensureSpace(space)
        }
        core.state.workspaces.activate("1")
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(9),
                    pid: 4242,
                    appName: "Notes",
                    appBundleID: "app.test.notes"
                )
            )
        )
        core.state.workspaces.add(WindowID(9), to: "2")
        return core
    }

    private let entry = JumpEntry(
        target: .window(WindowID(9)),
        pid: 4242,
        app: "Notes",
        title: "",
        space: "2",
        spaceIcon: nil,
        status: .shown
    )

    /// The fixture's control: a pick on a panel that is up moves
    /// the window here, so the refusal below is the guard's.
    @Test("a pick on an open panel runs Move here")
    func pickOnOpenPanel() {
        let core = coreWithAwayWindow()
        let controller = JumpPanelController(core: core)
        controller.reduceMotion = { true }
        let front = Front()
        front.wire(controller.handBack)
        controller.show()
        front.drain()
        defer { front.keyed.forEach { $0.orderOut(nil) } }
        controller.pick(entry, moveHere: true)
        #expect(core.state.workspaces.space(of: WindowID(9)) == "1")
    }

    /// The pick's close is refused while the exit fade runs, so
    /// the row's Move here never runs: the window stays put.
    @Test("a pick during the exit fade runs nothing")
    func pickDuringFade() {
        let core = coreWithAwayWindow()
        let controller = JumpPanelController(core: core)
        controller.reduceMotion = { true }
        let front = Front()
        front.wire(controller.handBack)
        controller.show()
        front.drain()
        defer { front.keyed.forEach { $0.orderOut(nil) } }
        controller.close()
        #expect(controller.panel?.isVisible == true)
        controller.pick(entry, moveHere: true)
        #expect(core.state.workspaces.space(of: WindowID(9)) == "2")
    }
}
