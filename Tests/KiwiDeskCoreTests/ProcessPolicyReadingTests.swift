import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// A process's one policy reading and its liveness reads (#1785):
/// LaunchServices loses a running process's record for a moment,
/// so a missing record is `.prohibited` only for a process the
/// process table says is gone. Split from `ProcessIdentityTests`
/// at the file ceiling; same seams, its own per-file harness
/// (tests.md).
@MainActor
@Suite("Process policy reading (#1785)")
struct ProcessPolicyReadingTests {
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
        var created: [pid_t] = []
        var windowQueries: [pid_t] = []
        var lookups: [pid_t] = []
        var alive: [pid_t: RunningApp] = [:]
        var active: [pid_t: Bool] = [:]
        var events: [KiwiEvent] = []
        var focused: [WindowID] = []
    }

    private static let bundle = "test.kiwi.browser"
    private let parent: pid_t = 178_501
    private let child: pid_t = 178_502
    private let other: pid_t = 178_503

    private func app(
        _ pid: pid_t,
        bundle: String = Self.bundle
    ) -> RunningApp {
        RunningApp(
            pid: pid,
            activationPolicy: .regular,
            ref: AppRef(bundleID: bundle, name: "Browser")
        )
    }

    /// The listing Orion produced: the parent under its pid, the
    /// child under -1, beside an unrelated app.
    private var listing: [RunningApp] {
        [app(parent), app(-1), app(other, bundle: "test.kiwi.other")]
    }

    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { pid in
            box.created.append(pid)
            return FakeObserver()
        }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { pid in
            box.windowQueries.append(pid)
            return []
        }
        loop.activationPolicy = { _ in .regular }
        loop.onScreenNormalWindowIDs = { box.census }
        loop.onEvent = { event in
            box.events.append(event)
            if case .windowFocused(let id) = event {
                box.focused.append(id)
            }
        }
        loop.processIdentity.appAt = { pid in
            box.lookups.append(pid)
            return box.alive[pid]
        }
        loop.processIdentity.runs = { box.alive[$0] != nil }
        loop.processIdentity.isActive = { box.active[$0] }
        loop.runningApplications = { [] }
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        loop.runningApplications = { self.listing }
        box.alive = [
            parent: app(parent), child: app(child),
            other: app(other, bundle: "test.kiwi.other"),
        ]
        return (loop, box)
    }

    private func element(_ pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    // MARK: - The policy reading

    // MARK: - The policy reading

    @Test("a record lost for a moment keeps a running process")
    func lostRecordKeepsARunningProcess() {
        let (loop, box) = makeLoop()
        box.census = [parent: [WindowID(1)]]
        loop.healSweep()
        var logs: [String] = []
        loop.onLog = { logs.append($0) }
        loop.activationPolicy = { _ in nil }
        #expect(loop.policy(of: parent) == .regular)
        #expect(loop.policy(of: parent) == .regular)
        // One absence, one line.
        #expect(logs.filter { $0.hasPrefix("ownership:") }.count == 1)
        loop.reconcile(pid: parent, app: app(parent).ref)
        #expect(loop.observes(pid: parent))
        // The record back, then lost again: news again.
        loop.activationPolicy = { _ in .regular }
        #expect(loop.policy(of: parent) == .regular)
        loop.activationPolicy = { _ in nil }
        #expect(loop.policy(of: parent) == .regular)
        #expect(logs.filter { $0.hasPrefix("ownership:") }.count == 2)
    }

    @Test("an unnamed exit keeps a running process whose record is lost")
    func unnamedExitReadsTheProcessTable() {
        let (loop, box) = makeLoop()
        box.census = [parent: [WindowID(1)], child: [WindowID(2)]]
        loop.healSweep()
        // The record lost, the process alive: the device case.
        loop.processIdentity.appAt = { _ in nil }
        loop.retireExitedObservers()
        #expect(loop.observes(pid: parent))
        #expect(loop.observes(pid: child))
        #expect(loop.processIdentity.unlisted[child] == Self.bundle)
        // Gone by the process table, record or not: retired.
        box.alive[child] = nil
        loop.retireExitedObservers()
        #expect(!loop.observes(pid: child))
        #expect(loop.observes(pid: parent))
    }

    @Test("a missing record detaches a process that is gone")
    func lostRecordDetachesAGoneProcess() {
        let (loop, box) = makeLoop()
        box.census = [parent: [WindowID(1)]]
        loop.healSweep()
        loop.activationPolicy = { _ in nil }
        box.alive[parent] = nil
        #expect(loop.policy(of: parent) == .prohibited)
        loop.reconcile(pid: parent, app: app(parent).ref)
        #expect(!loop.observes(pid: parent))
    }

    @Test("a process never observed has no policy to keep")
    func unobservedProcessIsProhibited() {
        let (loop, _) = makeLoop()
        loop.activationPolicy = { _ in nil }
        #expect(loop.policy(of: other) == .prohibited)
    }

    @Test("the policy read last is the one kept")
    func keptPolicyFollowsTheLastRead() {
        let (loop, box) = makeLoop()
        box.census = [parent: [WindowID(1)]]
        loop.healSweep()
        loop.activationPolicy = { _ in .accessory }
        #expect(loop.policy(of: parent) == .accessory)
        loop.activationPolicy = { _ in nil }
        #expect(loop.policy(of: parent) == .accessory)
    }

    @Test("an unlisted process that stopped running leaves the register")
    func stoppedUnlistedProcessIsForgotten() {
        let (loop, box) = makeLoop()
        box.census = [child: [WindowID(2)]]
        loop.healSweep()
        #expect(loop.processIdentity.unlisted[child] == Self.bundle)
        box.alive[child] = nil
        _ = loop.liveApps(owners: [])
        #expect(loop.processIdentity.unlisted[child] == nil)
    }
}
