import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **An activation's and a focus change's reconcile read the
/// window list OFF the main actor** (#1930): a slow app's list
/// read held the main actor for up to 700 ms on every Space
/// switch under GPU load.
///
/// Driven through `appActivated` on stubbed seams, the list read
/// captured for the test to pump: nothing the list decides lands
/// before the pump, and the flight is kept out of the sweep.
@Suite("Reconcile off main (#1930)")
@MainActor
struct ReconcileOffMainTests {
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
    private let other: pid_t = 616_616
    private let id = WindowID(21)
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.offmain", name: "OffMain")
    }

    private func app(_ pid: pid_t) -> RunningApp {
        RunningApp(pid: pid, activationPolicy: .regular, ref: ref)
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

    @Test("an activation reads both its reads off the main actor")
    func activationReadsOffMain() {
        let (loop, box) = makeLoop()
        box.focus = id
        box.listed = [id]
        loop.appActivated(app(pid), launchedAt: nil)
        #expect(box.listReads == 0, "list read inline")
        #expect(box.focusReads == 0, "focus read inline")
        #expect(box.focused.isEmpty, "reported inline")
        box.drain()
        #expect(box.listReads == 1)
        #expect(box.focusReads == 1)
        #expect(box.focused == [id])
    }

    @Test("an activation's reconcile lands after its read")
    func activationReconcilesAfterTheRead() {
        let (loop, box) = makeLoop()
        loop.appActivated(app(pid), launchedAt: nil)
        #expect(box.destroyed.isEmpty, "reconciled inline")
        box.drain()
        #expect(box.destroyed == [id])
    }

    @Test("the app left is reconciled off the main actor too")
    func previousAppReadsOffMain() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = pid
        loop.appActivated(app(other), launchedAt: nil)
        #expect(box.listReads == 0, "read inline")
        box.drain()
        #expect(box.destroyed == [id])
    }

    @Test("a focus change reads the list off the main actor")
    func focusChangeReadsOffMain() {
        let (loop, box) = makeLoop()
        loop.handleFocusedWindowChanged(
            AXUIElementCreateApplication(pid),
            pid: pid,
            app: ref
        )
        #expect(box.listReads == 0, "read inline")
        #expect(box.destroyed.isEmpty, "reconciled inline")
        box.drain()
        #expect(box.listReads == 1)
    }

    @Test("a window tracked during the read stays tracked")
    func trackedDuringFlightIsKept() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = pid
        loop.appActivated(app(other), launchedAt: nil)
        // A create lands between the read and its apply: the
        // list predates it, so it cannot speak for it.
        let late = WindowID(22)
        loop.elements[pid]?[late] = AXUIElementCreateApplication(pid)
        box.drain()
        #expect(box.destroyed == [id])
        #expect(loop.elements[pid]?[late] != nil)
    }

    /// The wait itself — a window the reconcile adopts — is
    /// `ReconcileOffMainDebtTests`' (`untrackedFocusJoinsThePendingRead`).
    @Test("an untracked focus that stays untracked classifies")
    func untrackedFocusClassifies() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [:]
        box.focus = WindowID(23)
        loop.appActivated(app(pid), launchedAt: nil)
        #expect(!box.logs.contains { $0.contains("w23") })
        box.drain()
        #expect(box.logs.contains { $0.contains("untracked w23") })
        #expect(box.focused.isEmpty)
    }

    @Test("a later activation supersedes a waiting report")
    func laterActivationSupersedes() {
        let (loop, box) = makeLoop()
        let late = WindowID(24)
        box.focus = late
        loop.appActivated(app(pid), launchedAt: nil)
        // The reconcile adopts nothing here; the window becomes
        // tracked by hand so only the supersession can drop it.
        loop.elements[pid]?[late] = AXUIElementCreateApplication(pid)
        loop.lastActivePid = other
        box.drain()
        #expect(box.focused.isEmpty, "reported \(box.focused)")
    }

    @Test("a focus commanded during the read drops the report")
    func commandedFocusSupersedes() {
        let (loop, box) = makeLoop()
        let late = WindowID(25)
        box.focus = late
        loop.appActivated(app(pid), launchedAt: nil)
        loop.elements[pid]?[late] = AXUIElementCreateApplication(pid)
        loop.lastCommandedFocus = .now
        box.drain()
        #expect(box.focused.isEmpty, "reported \(box.focused)")
        #expect(box.logs.contains { $0.contains("focus stale") })
    }

    @Test("a waiting report still lands")
    func waitingReportLands() {
        // The negative control for the two supersessions above.
        let (loop, box) = makeLoop()
        let late = WindowID(26)
        box.focus = late
        loop.appActivated(app(pid), launchedAt: nil)
        loop.elements[pid]?[late] = AXUIElementCreateApplication(pid)
        box.drain()
        #expect(box.focused == [late])
    }
}

/// The two set operations that keep a list read's flight out of
/// the sweep (#1930).
@Suite("Prefetched window flight (#1930)")
struct PrefetchedWindowsFlightTests {
    private let element = AXUIElementCreateApplication(1)

    @Test("a window tracked during the read is kept live")
    func trackedDuringFlightIsLive() {
        let flight = PrefetchedWindows(
            elements: [],
            trackedAtRead: [WindowID(1)]
        )
        var live: Set<WindowID> = []
        var appeared: [(element: AXUIElement, id: WindowID)] = []
        flight.excuseFlight(
            tracked: [WindowID(1), WindowID(2)],
            live: &live,
            appeared: &appeared
        )
        #expect(live == [WindowID(2)])
    }

    @Test("a window gone during the read is not re-adopted")
    func goneDuringFlightIsNotAdopted() {
        let flight = PrefetchedWindows(
            elements: [],
            trackedAtRead: [WindowID(1), WindowID(2)]
        )
        var live: Set<WindowID> = [WindowID(2)]
        var appeared = [(element: element, id: WindowID(1))]
        flight.excuseFlight(
            tracked: [],
            live: &live,
            appeared: &appeared
        )
        #expect(appeared.isEmpty)
        #expect(live.isEmpty)
    }
}
