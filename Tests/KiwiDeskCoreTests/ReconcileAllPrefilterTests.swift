import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The bulk reconcile's WindowServer gate (#1037). A Desktop
/// switch used to ask EVERY observed app for its AX window
/// list, and an app not servicing AX — App-Napped with its
/// windows on other Desktops, or a headless agent — blocked
/// the main actor for the whole messaging timeout, ~1 s each
/// in series, on every switch. The gate reads one census
/// instead and skips an app that tracks nothing and shows
/// nothing; the Desktop settle then sweeps the arrivals the
/// notification beat. This suite pins the pure gate, the two
/// wirings that read it, and the arrival sweep's arms. Everything
/// drives the funnels through the injected machine seams
/// (tests.md); the only AX object a test creates is an app
/// element used as an inert dictionary value, never messaged.
/// The settle's call is pinned in `FullscreenStandDownTests`
/// (`+ArrivalSweep`), because the settle body reads the
/// process-global `isUser` override that suite alone holds.
///
/// Main-actor spend: fakes only — no core, no run loop.
@MainActor
@Suite("Bulk reconcile census gate (#1037)")
struct ReconcileAllPrefilterTests {
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        let needsRegistrationRepair = false
        func observe(window: AXUIElement) {}
        func repairRegistration() {}
        func invalidate() {}
    }

    @MainActor
    private final class Box {
        /// The pids whose AX window list was read, in order.
        var queried: [pid_t] = []
        /// The pids `reconcile` was handed at all: it reads the
        /// activation policy for every pid before its ownership
        /// guard, so this sees a call `queried` cannot.
        var handed: [pid_t] = []
        var censusReads = 0
        var census: [pid_t: Set<WindowID>] = [:]
    }

    private let napping: pid_t = 1_037_001
    private let showing: pid_t = 1_037_002

    private func app(_ pid: pid_t) -> RunningApp {
        RunningApp(
            pid: pid,
            activationPolicy: .regular,
            ref: AppRef(bundleID: "test.kiwi.\(pid)", name: "\(pid)")
        )
    }

    /// A started loop observing both apps, with the census and
    /// the window-list read routed through the box.
    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.runningApplications = { [] }
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { pid in
            box.queried.append(pid)
            return []
        }
        loop.activationPolicy = { pid in
            box.handed.append(pid)
            return .regular
        }
        loop.onScreenNormalWindowIDs = {
            box.censusReads += 1
            return box.census
        }
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        for pid in [napping, showing] {
            loop.attach(
                pid: pid,
                activationPolicy: .regular,
                ref: app(pid).ref,
                scanWindowsAtAttach: false
            )
        }
        loop.runningApplications = { [self.app(napping), self.app(showing)] }
        return (loop, box)
    }

    /// An inert AX value for seeding `elements` directly — an
    /// app element is never messaged by the gate.
    private func dummyElement(_ pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    // MARK: - The pure gate

    @Test("an app is reached when it tracks or shows a window")
    func gateReachesTrackingOrShowing() {
        let census: [pid_t: Set<WindowID>] = [
            2: [WindowID(20)],
            4: [],
        ]
        let targets = EventLoop.reconcileAllTargets(
            observed: [1, 2, 3, 4],
            census: census,
            tracks: { $0 == 1 }
        )
        // 1 tracks, 2 shows; 3 does neither and 4's census
        // entry is empty — the same "shows nothing".
        #expect(targets == [1, 2])
    }

    @Test("the gate keeps the caller's order")
    func gateKeepsOrder() {
        let targets = EventLoop.reconcileAllTargets(
            observed: [9, 7, 8],
            census: [:],
            tracks: { _ in true }
        )
        #expect(targets == [9, 7, 8])
    }

    // MARK: - reconcileAll reads the gate

    @Test("reconcileAll skips an app tracking and showing nothing")
    func reconcileAllSkipsTheNappingApp() {
        let (loop, box) = makeLoop()
        defer { loop.stop() }
        box.census = [showing: [WindowID(1)]]
        loop.reconcileAll()
        #expect(box.queried == [showing])
    }

    @Test("reconcileAll reaches an app that tracks a window")
    func reconcileAllReachesTheTrackingApp() {
        let (loop, box) = makeLoop()
        defer { loop.stop() }
        // Tracked but not on screen: the departed side of a
        // switch, which the pass exists to remove.
        loop.elements[napping] = [WindowID(5): dummyElement(napping)]
        loop.reconcileAll()
        #expect(box.queried == [napping])
    }

    // MARK: - The settle's arrival sweep

    @Test("the arrival sweep reads only an untracked on-screen window")
    func arrivalSweepReadsUntrackedOnly() {
        let (loop, box) = makeLoop()
        defer { loop.stop() }
        loop.elements[showing] = [WindowID(1): dummyElement(showing)]
        // Fully tracked: nothing to adopt, no read.
        box.census = [showing: [WindowID(1)]]
        loop.reconcileOnScreenArrivals()
        #expect(box.queried.isEmpty)
        // A second id landed after the switch pass: read.
        box.census = [showing: [WindowID(1), WindowID(2)]]
        loop.reconcileOnScreenArrivals()
        #expect(box.queried == [showing])
    }

    @Test("the arrival sweep leaves an unobserved app to the heal")
    func arrivalSweepSkipsUnobserved() {
        let (loop, box) = makeLoop()
        defer { loop.stop() }
        box.census = [1_037_999: [WindowID(3)]]
        loop.reconcileOnScreenArrivals()
        // `queried` alone cannot see this filter: a reconcile
        // handed an unobserved pid detaches before it reads the
        // window list. The policy read precedes that guard.
        #expect(!box.handed.contains(1_037_999))
        #expect(box.queried.isEmpty)
    }

    @Test("the arrival sweep is inert on a stopped loop")
    func arrivalSweepInertWhenStopped() {
        let (loop, box) = makeLoop()
        box.census = [showing: [WindowID(1)]]
        loop.stop()
        box.censusReads = 0
        loop.reconcileOnScreenArrivals()
        // `stop()` empties `observers`, so an emptied filter would
        // pass `queried` too; what the guard uniquely spares is
        // the census read itself — a live CGWindowList call.
        #expect(box.censusReads == 0)
        #expect(box.queried.isEmpty)
    }
}
