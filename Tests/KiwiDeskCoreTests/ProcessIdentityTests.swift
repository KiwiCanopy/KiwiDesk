import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// A pid LaunchServices cannot name is never an identity (#1785).
/// Orion's second profile is a LaunchServices child: listed with
/// pid -1, its activation announced under its parent's pid, while
/// the WindowServer files its windows under its real one. Driven
/// through the injected machine seams (tests.md); an AX app
/// element appears only as an inert dictionary value.
@MainActor
@Suite("Process identity (#1785)")
struct ProcessIdentityTests {
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
        var front: [(id: WindowID, pid: pid_t)] = []
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
        loop.processIdentity.frontToBack = { box.front }
        loop.processIdentity.afterReorder = { $0() }
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

    @Test("the heal adopts a census pid the app list lacks")
    func healAdoptsTheUnlistedProcess() {
        let (loop, box) = makeLoop()
        box.census = [child: [WindowID(830_336)]]
        loop.healSweep()
        #expect(loop.observes(pid: child))
        #expect(box.windowQueries == [child])
        #expect(loop.processIdentity.unlisted[child] == Self.bundle)
    }

    @Test("a pid of zero or below never attaches")
    func unnamedPidNeverAttaches() {
        let (loop, box) = makeLoop()
        for pid: pid_t in [-1, -2, 0] {
            loop.syncObservation(for: app(pid), scanWindowsAtAttach: true)
            loop.attach(
                pid: pid,
                activationPolicy: .regular,
                ref: app(pid).ref,
                scanWindowsAtAttach: true
            )
        }
        #expect(box.created.isEmpty)
        #expect(loop.observers.isEmpty)
    }

    @Test("listed apps are never looked up by pid")
    func listedAppsTakeTodaysPath() {
        let (loop, box) = makeLoop()
        box.census = [parent: [WindowID(1)], other: [WindowID(2)]]
        loop.healSweep()
        #expect(box.lookups.isEmpty)
        #expect(loop.observes(pid: parent))
        #expect(loop.observes(pid: other))
        #expect(loop.processIdentity.unlisted.isEmpty)
    }

    @Test("an unannounced exit retires only the gone process")
    func unannouncedExitRetiresTheGoneProcess() {
        let (loop, box) = makeLoop()
        box.census = [
            parent: [WindowID(1)], child: [WindowID(2)],
            other: [WindowID(3)],
        ]
        loop.healSweep()
        loop.elements[child] = [WindowID(2): element(child)]
        box.alive[child] = nil
        loop.retireExitedObservers()
        #expect(!loop.observes(pid: child))
        #expect(loop.observes(pid: parent))
        #expect(loop.observes(pid: other))
        #expect(loop.processIdentity.unlisted[child] == nil)
        #expect(
            box.events.contains {
                if case .appTerminated(let pid) = $0 {
                    pid == child
                } else {
                    false
                }
            }
        )
        #expect(
            box.events.contains {
                if case .windowDestroyed(let id, _) = $0 {
                    id == WindowID(2)
                } else {
                    false
                }
            }
        )
    }

    @Test("the gate counts a sibling of the active process")
    func gateCountsTheSibling() {
        let (loop, box) = makeLoop()
        box.census = [
            parent: [WindowID(1)], child: [WindowID(2)],
            other: [WindowID(3)],
        ]
        loop.healSweep()
        loop.lastActivePid = parent
        #expect(loop.reportsFromActiveApp(parent))
        #expect(loop.reportsFromActiveApp(child))
        #expect(!loop.reportsFromActiveApp(other))
        loop.lastActivePid = other
        #expect(!loop.reportsFromActiveApp(child))
    }

    @Test("two listed processes of one bundle stay strangers")
    func listedPairsAreNotSiblings() {
        let (loop, box) = makeLoop()
        let twin: pid_t = 178_504
        box.alive[twin] = app(twin)
        loop.runningApplications = { [self.app(parent), self.app(twin)] }
        box.census = [parent: [WindowID(1)], twin: [WindowID(4)]]
        loop.healSweep()
        loop.lastActivePid = parent
        #expect(!loop.reportsFromActiveApp(twin))
        #expect(loop.siblingProcesses(of: parent).isEmpty)
    }

    @Test("an unnamed frontmost reading leaves the gate open")
    func unnamedFrontmostFailsOpen() {
        let (loop, _) = makeLoop()
        loop.lastActivePid = nil
        loop.frontmostPID = { -1 }
        #expect(loop.reportsFromActiveApp(other))
    }

    @Test("a sibling activation focuses the family's front window")
    func siblingActivationTakesTheFrontWindow() {
        let (loop, box) = makeLoop()
        box.census = [parent: [WindowID(1)], child: [WindowID(2)]]
        loop.healSweep()
        loop.elements[parent] = [WindowID(1): element(parent)]
        loop.elements[child] = [WindowID(2): element(child)]
        loop.lastActivePid = parent
        // Another app's window above the family is passed over;
        // the parent's own focused window is not the answer.
        box.front = [
            (WindowID(3), other), (WindowID(2), child),
            (WindowID(1), parent),
        ]
        let family = loop.siblingProcesses(of: parent).union([parent])
        #expect(family == [parent, child])
        box.focused = []
        loop.reportFrontWindow(of: family)
        #expect(box.focused == [WindowID(2)])
    }

    @Test("an untracked or stale front window reports nothing")
    func unresolvedFrontWindowReportsNothing() {
        let (loop, box) = makeLoop()
        box.census = [parent: [WindowID(1)], child: [WindowID(2)]]
        loop.healSweep()
        loop.lastActivePid = parent
        box.front = [(WindowID(2), child)]
        box.focused = []
        loop.reportFrontWindow(of: [parent, child])
        #expect(box.focused.isEmpty)
        // Tracked, but another app took over during the reorder.
        loop.elements[child] = [WindowID(2): element(child)]
        loop.lastActivePid = other
        loop.reportFrontWindow(of: [parent, child])
        #expect(box.focused.isEmpty)
    }
}
