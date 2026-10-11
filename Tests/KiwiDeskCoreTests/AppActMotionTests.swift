import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The user's own act in an app is not ambient motion (#2187): a
/// close that took the active Space's focus, or a window the
/// frontmost app opened, within a press's grace lays out at once
/// under a moving mouse. A background app's window and a close with
/// no press behind it still wait for the hand (#804).
@Suite("App act motion (#2187)", .serialized)
@MainActor
struct AppActMotionTests {
    @MainActor
    private final class Desk {
        typealias F = BootRestoreFixture
        let core: KiwiCore
        var pressAge: TimeInterval? = 0.1
        var frontmost: pid_t? = nil
        var issued: [WindowID] = []

        init() throws {
            let windows = (1...3).map {
                F.Window(
                    id: WindowID(UInt32($0)),
                    space: F.shown,
                    frame: CGRect(x: 0, y: 0, width: 10, height: 10)
                )
            }
            core = try #require(F.processA(windows))
            core.state.workspaces.focus(WindowID(1), in: F.shown)
            let gate = core.tiler.motionGate
            gate.schedule = { _, _ in }
            gate.onLog = { _ in }
            // The mouse is moving: an ambient pass is held.
            gate.quiescence.sinceMouseMoved = { 0 }
            core.launchFollow.pressAge = { [unowned self] in
                self.pressAge
            }
            core.frontmostPIDProvider = { [unowned self] in
                self.frontmost
            }
            core.tiler.applier.issued = { [unowned self] id, _ in
                self.issued.append(id)
            }
        }

        var owed: Bool { core.tiler.motionGate.owed != nil }

        func arrival(_ id: UInt32) -> ManagedWindow {
            F.managed(
                F.Window(
                    id: WindowID(id),
                    space: F.shown,
                    frame: CGRect(x: 0, y: 0, width: 10, height: 10)
                )
            )
        }
    }

    @Test("Closing the focused window right after a press lays out now")
    func focusedCloseRuns() throws {
        let desk = try Desk()
        desk.core.handle(.windowDestroyed(WindowID(1), wasMinimized: false))
        #expect(!desk.issued.isEmpty)
        #expect(!desk.owed)
    }

    @Test("A focused close with no press behind it waits for the hand")
    func unpressedCloseWaits() throws {
        let desk = try Desk()
        desk.pressAge = LaunchFollowIntent.pressGrace + 1
        desk.core.handle(.windowDestroyed(WindowID(1), wasMinimized: false))
        #expect(desk.issued.isEmpty)
        #expect(desk.owed)
    }

    @Test("Closing an unfocused window waits for the hand")
    func unfocusedCloseWaits() throws {
        let desk = try Desk()
        desk.core.handle(.windowDestroyed(WindowID(2), wasMinimized: false))
        #expect(desk.issued.isEmpty)
        #expect(desk.owed)
    }

    @Test("A window the frontmost app opens after a press lays out now")
    func frontmostOpenRuns() throws {
        let desk = try Desk()
        let window = desk.arrival(9)
        desk.frontmost = window.pid
        desk.core.handle(.windowCreated(window))
        #expect(desk.issued.contains(window.id))
        #expect(!desk.owed)
    }

    @Test("A background app's new window waits for the hand")
    func backgroundOpenWaits() throws {
        let desk = try Desk()
        let window = desk.arrival(9)
        desk.frontmost = window.pid + 1
        desk.core.handle(.windowCreated(window))
        #expect(desk.issued.isEmpty)
        #expect(desk.owed)
    }
}
