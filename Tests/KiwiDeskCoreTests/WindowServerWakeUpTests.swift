import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **A WindowServer destroy wakes the AX path only for a window
/// still tracked** (#1877), and reads its app off the main actor.
/// The list read is captured for the test to pump —
/// `ReconcileOffMainTests`' fixture shape. The create half is
/// `WindowServerHealPullTests`'.
@Suite("WindowServer wake-up (#1877)")
@MainActor
struct WindowServerWakeUpTests {
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

    private let fresh = WindowID(33)

    @Test("an unanswered destroy of a tracked window wakes its app")
    func unansweredDestroyWakes() {
        let (loop, box) = makeLoop()
        loop.windowServerDestroyed(id)
        #expect(box.listReads == 0, "read inline")
        #expect(box.destroyed.isEmpty, "reconciled inline")
        box.drain()
        #expect(box.destroyed == [id])
    }

    @Test("a destroy of an untracked window costs no read")
    func untrackedDestroyIsQuiet() {
        let (loop, box) = makeLoop()
        loop.windowServerDestroyed(fresh)
        box.drain()
        #expect(box.listReads == 0)
        #expect(!box.logs.contains { $0.hasPrefix("wake-up") })
    }

    @Test("a stopped loop wakes nothing")
    func stoppedLoopIsQuiet() {
        let (loop, box) = makeLoop()
        loop.stop()
        loop.windowServerDestroyed(id)
        box.drain()
        #expect(box.listReads == 0)
    }

    @Test("the payload carries the window id at offset 8")
    func payloadOffset() {
        var bytes: [UInt32] = [1, 0, 220_134]
        let read = bytes.withUnsafeMutableBytes {
            SkyLightWindowLifecycle.windowID(
                in: $0.baseAddress,
                length: $0.count
            )
        }
        #expect(read == WindowID(220_134))
        let short = bytes.withUnsafeMutableBytes {
            SkyLightWindowLifecycle.windowID(
                in: $0.baseAddress,
                length: 8
            )
        }
        #expect(short == nil)
    }
}
