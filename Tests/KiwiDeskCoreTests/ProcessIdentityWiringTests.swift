import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #1785 lifecycle wiring: the workspace handlers reach the
/// process-identity decisions `ProcessIdentityTests` pins, and the
/// front-window read's edges. Split from that suite at the file
/// ceiling; same seams, its own per-file harness (tests.md).
@MainActor
@Suite("Process identity wiring (#1785)")
struct ProcessIdentityWiringTests {
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        var needsRegistrationRepair = false
        func observe(window: AXUIElement) {}
        func repairRegistration() {}
        func invalidate() {}
    }

    @MainActor
    private final class Box {
        var census: [pid_t: Set<WindowID>] = [:]
        var alive: [pid_t: RunningApp] = [:]
        var focused: [WindowID] = []
        var terminated: [pid_t] = []
        var logs: [String] = []
    }

    private static let bundle = "test.kiwi.browser"
    private let parent: pid_t = 178_601
    private let child: pid_t = 178_602

    private func app(_ pid: pid_t) -> RunningApp {
        RunningApp(
            pid: pid,
            activationPolicy: .regular,
            ref: AppRef(bundleID: Self.bundle, name: "Browser")
        )
    }

    /// A loop observing the parent and, through the heal, its
    /// unlisted child — both windows tracked.
    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { box.logs.append($0) }
        loop.registersWorkspaceObservers = false
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { _ in [] }
        loop.activationPolicy = { _ in .regular }
        loop.onScreenNormalWindowIDs = { box.census }
        loop.onEvent = { event in
            switch event {
            case .windowFocused(let id): box.focused.append(id)
            case .appTerminated(let pid): box.terminated.append(pid)
            default: break
            }
        }
        loop.processIdentity.appAt = { box.alive[$0] }
        loop.runningApplications = { [] }
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        loop.runningApplications = { [self.app(parent), self.app(-1)] }
        box.alive = [parent: app(parent), child: app(child)]
        box.census = [parent: [WindowID(1)], child: [WindowID(2)]]
        loop.healSweep()
        loop.elements[parent] = [WindowID(1): element(parent)]
        loop.elements[child] = [WindowID(2): element(child)]
        box.focused = []
        return (loop, box)
    }

    private func element(_ pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    @Test("a parent's activation defers to the processes' reports")
    func parentActivationDefers() {
        let (loop, box) = makeLoop()
        box.logs = []
        loop.appActivated(app(parent), launchedAt: nil)
        #expect(loop.lastActivePid == parent)
        #expect(
            box.logs.contains {
                $0.hasPrefix("activation: pid \(parent) runs beside")
            }
        )
    }

    @Test("an unnamed activation leaves the gate with no reading")
    func unnamedActivationClearsTheReading() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = parent
        loop.appActivated(app(-1), launchedAt: nil)
        #expect(loop.lastActivePid == nil)
        #expect(box.focused.isEmpty)
    }

    @Test("an unnamed exit retires the gone child through the handler")
    func unnamedExitReachesTheRetire() {
        let (loop, box) = makeLoop()
        box.alive[child] = nil
        loop.appTerminated(pid: -1)
        #expect(!loop.observes(pid: child))
        #expect(loop.observes(pid: parent))
        #expect(box.terminated == [child])
    }

    @Test("a named exit keeps today's path")
    func namedExitDetachesThatPid() {
        let (loop, box) = makeLoop()
        loop.appTerminated(pid: parent)
        #expect(!loop.observes(pid: parent))
        #expect(loop.observes(pid: child))
        #expect(box.terminated == [parent])
    }

    @Test("stop forgets the unlisted processes")
    func stopClearsTheUnlistedMap() {
        let (loop, _) = makeLoop()
        #expect(loop.processIdentity.unlisted[child] == Self.bundle)
        loop.stop()
        #expect(loop.processIdentity.unlisted.isEmpty)
    }

    @Test("an unnamed exit never retires KiwiDesk itself")
    func ownProcessIsNeverRetired() {
        let (loop, _) = makeLoop()
        let own = getpid()
        loop.attach(
            pid: own,
            activationPolicy: .regular,
            ref: AppRef(bundleID: "test.kiwi.self", name: "Self"),
            scanWindowsAtAttach: false
        )
        #expect(loop.observes(pid: own))
        loop.retireExitedObservers()
        #expect(loop.observes(pid: own))
    }
}
