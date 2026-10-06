import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **A close reads the window list OFF the main actor unless the
/// arm deferred it** (#1888): one Finder close held the main
/// actor for up to 930 ms. A deferred close (a tab carrier or a
/// carrier's sibling) stays synchronous, since its removal must
/// beat the successor's focus report (#936).
///
/// Driven through `handle` on stubbed seams, the list read
/// captured for the test to pump — `ReconcileOffMainTests`'
/// fixture shape.
@Suite("Close reconcile off main (#1888)")
@MainActor
struct ReconcileOffMainCloseTests {
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
        var focused: [WindowID] = []
        var destroyed: [WindowID] = []
        var logs: [String] = []
        var listReads = 0
        var focusReads = 0
        /// The ids the AX list answers; empty destroys window 21.
        var listed: [WindowID] = []
        var work: [@Sendable () -> Void] = []
        var focus: WindowID?

        func drain() {
            while !work.isEmpty { work.removeFirst()() }
        }
    }

    private let pid: pid_t = 717_717
    private let id = WindowID(21)
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.offmain", name: "OffMain")
    }

    /// A loop observing `pid` with window 21 tracked and the AX
    /// list answering NOTHING unless a test lists it — so a
    /// reconcile that ran destroys it, which is how a test sees
    /// whether it ran yet.
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
        loop.appIsHidden = { _ in false }
        loop.frontmostPID = { nil }
        loop.shadows.focusedWindow = { _ in
            MainActor.assumeIsolated {
                box.focusReads += 1
                return box.focus
            }
        }
        let dummy = AXUIElementCreateApplication(pid)
        loop.axWindows = { _ in
            let count = MainActor.assumeIsolated {
                box.listReads += 1
                return box.listed.count
            }
            return Array(repeating: dummy, count: count)
        }
        loop.resolveWindowID = { _ in
            MainActor.assumeIsolated { box.listed.first }
        }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        loop.axReads.dispatchOverride = { _, work in
            box.work.append(work)
        }
        loop.onEvent = { event in
            switch event {
            case .windowFocused(let id): box.focused.append(id)
            case .windowDestroyed(let id, _): box.destroyed.append(id)
            default: break
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
        loop.elements[pid] = [id: AXUIElementCreateApplication(pid)]
        return (loop, box)
    }

    @Test("a close the map cannot name reconciles off main")
    func unmappedDestroyReadsOffMain() {
        let (loop, box) = makeLoop()
        loop.handle(
            kAXUIElementDestroyedNotification,
            AXUIElementCreateSystemWide(),
            pid: pid,
            app: ref
        )
        // Its window was swept ahead of the notification, so only
        // a skipped close is left for the read (#1888).
        #expect(box.listReads == 0, "list read inline (#1888)")
        box.drain()
        #expect(box.listReads == 1)
        #expect(box.destroyed == [id])
    }

    @Test("a deferred tab-carrier close reconciles at once")
    func deferredDestroyReconcilesInline() {
        let (loop, box) = makeLoop()
        loop.tabCarriers.insert(id)
        loop.handle(
            kAXUIElementDestroyedNotification,
            AXUIElementCreateApplication(pid),
            pid: pid,
            app: ref
        )
        #expect(box.listReads == 1)
        #expect(box.destroyed == [id])
    }

    @Test("a close beside a tab carrier reconciles at once")
    func carrierSiblingDestroyReconcilesInline() {
        let (loop, box) = makeLoop()
        loop.tabCarriers.insert(WindowID(22))
        loop.elements[pid]?[WindowID(22)] = AXUIElementCreateSystemWide()
        loop.handle(
            kAXUIElementDestroyedNotification,
            AXUIElementCreateApplication(pid),
            pid: pid,
            app: ref
        )
        #expect(box.listReads == 1)
        #expect(box.destroyed.contains(id))
    }

    @Test("a tracked close reports at once, its list read off main")
    func trackedDestroyReportsInline() {
        let (loop, box) = makeLoop()
        loop.handle(
            kAXUIElementDestroyedNotification,
            AXUIElementCreateApplication(pid),
            pid: pid,
            app: ref
        )
        #expect(box.destroyed == [id])
        #expect(box.listReads == 0, "list read inline (#1888)")
        box.drain()
        #expect(box.listReads == 1)
        #expect(box.destroyed == [id])
    }

    @Test("a minimize reports at once, its list read off main")
    func minimizeReportsInline() {
        let (loop, box) = makeLoop()
        loop.handle(
            kAXWindowMiniaturizedNotification,
            AXUIElementCreateApplication(pid),
            pid: pid,
            app: ref
        )
        #expect(box.destroyed == [id])
        #expect(box.listReads == 0, "list read inline (#1888)")
        box.drain()
        #expect(box.listReads == 1)
    }
}
