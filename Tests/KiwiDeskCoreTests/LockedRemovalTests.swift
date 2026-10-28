import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The removal pause under a locked session (#2538). A display
/// waking behind the lock drops every window from the on-screen
/// census for a moment, so #1157 cannot refuse, and the sweep
/// closed the whole desk; at the unlock each window came back as
/// new, into its App Rule's Space (field log, 2026-10-28). While
/// locked a sweep removes nothing, and the apps it refused are
/// reconciled once the lock is gone. The harness is a per-file
/// copy of `ReconcileOffMainRecheckTests`' queued off-main read.
@MainActor
@Suite("Locked session refuses removals (#2538)")
struct LockedRemovalTests {
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
        var locked = true
        /// Whether the app's AX list names the window.
        var listed = false
        var logs: [String] = []
        var destroyed: [WindowID] = []
        var reads: [@Sendable () -> Void] = []
        var deliveries: [@MainActor @Sendable () -> Void] = []

        /// Runs every queued read and delivery, bounded.
        func drain() {
            for _ in 0..<20 where !(reads.isEmpty && deliveries.isEmpty) {
                while !reads.isEmpty { reads.removeFirst()() }
                while !deliveries.isEmpty { deliveries.removeFirst()() }
            }
        }
    }

    private let pid: pid_t = 925_380
    private let id = WindowID(2538)
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.locked", name: "Locked")
    }

    /// A loop observing `pid` with `id` tracked, an empty census
    /// and an AX list that names `id` only while `box.listed`.
    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { box.logs.append($0) }
        loop.registersWorkspaceObservers = false
        loop.runningApplications = { [] }
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.activationPolicy = { _ in .regular }
        loop.onScreenNormalWindowIDs = { [:] }
        loop.frontmostPID = { nil }
        loop.appIsHidden = { _ in false }
        loop.lockedRemovals.isLocked = { box.locked }
        let element = AXUIElementCreateApplication(pid)
        loop.axWindows = { _ in
            MainActor.assumeIsolated { box.listed } ? [element] : []
        }
        let id = id
        loop.resolveWindowID = { _ in id }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated { box.deliveries.append(work) }
        }
        loop.axReads.dispatchOverride = { _, work in
            box.reads.append(work)
        }
        loop.onEvent = { event in
            if case .windowDestroyed(let gone, _) = event {
                box.destroyed.append(gone)
            }
        }
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        loop.elements[pid] = [id: element]
        return (loop, box)
    }

    private func lockLines(_ box: Box) -> Int {
        box.logs.count { $0.contains("while the session is locked") }
    }

    @Test("a locked sweep removes nothing and logs once per app")
    func lockedSweepRemovesNothing() {
        let (loop, box) = makeLoop()
        loop.reconcile(pid: pid, app: ref)
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[id] != nil)
        #expect(loop.lockedRemovals.refused == [pid])
        #expect(lockLines(box) == 1)
    }

    @Test("an unlocked sweep removes the same window")
    func unlockedSweepRemoves() {
        let (loop, box) = makeLoop()
        box.locked = false
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed == [id])
        #expect(loop.lockedRemovals.refused.isEmpty)
    }

    @Test("a return still reading locked keeps the debt")
    func stillLockedKeepsTheDebt() {
        let (loop, box) = makeLoop()
        loop.reconcile(pid: pid, app: ref)
        loop.sessionDidReturn()
        // Nothing asked: a read now would only re-learn the lock.
        #expect(box.reads.isEmpty)
        box.drain()
        #expect(loop.lockedRemovals.refused == [pid])
        #expect(box.destroyed.isEmpty)
    }

    @Test("the return re-reads a refused app: a live window stays")
    func returnKeepsALiveWindow() {
        let (loop, box) = makeLoop()
        loop.reconcile(pid: pid, app: ref)
        box.locked = false
        box.listed = true
        loop.sessionDidReturn()
        box.drain()
        #expect(loop.lockedRemovals.refused.isEmpty)
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[id] != nil)
    }

    @Test("the return re-reads a refused app: a true close lands")
    func returnLandsATrueClose() {
        let (loop, box) = makeLoop()
        loop.reconcile(pid: pid, app: ref)
        box.locked = false
        loop.sessionDidReturn()
        box.drain()
        #expect(box.destroyed == [id])
    }

    @Test("a heal tick pays a debt the return could not")
    func healTickPaysTheDebt() {
        let (loop, box) = makeLoop()
        loop.reconcile(pid: pid, app: ref)
        loop.sessionDidReturn()
        box.locked = false
        loop.healSweep(census: [:])
        box.drain()
        #expect(loop.lockedRemovals.refused.isEmpty)
        #expect(box.destroyed == [id])
    }

    @Test("a destroyed element under the lock defers to the sweep")
    func destroyNotificationDefers() {
        // The notification arm reads the live process table, which
        // only our own pid answers (`CarriedDestroyArmTests`).
        let (loop, box) = makeLoop()
        let own = pid_t(getpid())
        let element = AXUIElementCreateApplication(own)
        loop.observers[own] = FakeObserver()
        loop.elements[own] = [id: element]
        loop.handle(
            kAXUIElementDestroyedNotification,
            element,
            pid: own,
            app: AppRef(bundleID: nil, name: "Own")
        )
        // Nothing eager; the refusal is the off-main sweep's
        // (#1888): one list read queued, none run on main.
        #expect(box.destroyed.isEmpty)
        #expect(box.reads.count == 1)
        box.drain()
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[own]?[id] != nil)
        #expect(loop.lockedRemovals.refused.contains(own))
    }

    @Test("a stop forgets every debt")
    func stopForgets() {
        let (loop, _) = makeLoop()
        loop.reconcile(pid: pid, app: ref)
        loop.stop()
        #expect(loop.lockedRemovals.refused.isEmpty)
    }

    @Test("a detach forgets the app's debt")
    func detachForgets() {
        let (loop, _) = makeLoop()
        loop.reconcile(pid: pid, app: ref)
        loop.detach(pid: pid, restoreEnhancedUI: false)
        #expect(loop.lockedRemovals.refused.isEmpty)
    }
}
