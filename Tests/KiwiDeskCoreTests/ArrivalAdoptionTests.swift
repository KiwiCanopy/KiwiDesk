import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **A window an off-main list read found arriving is adopted with
/// no main-actor AX call** (#2347's follow-up). The read takes what
/// `track` would otherwise ask the app — the snapshot, the facts,
/// detection, the shadow traits, fullscreen and native tabs — so
/// a Desktop switch's arrivals cost the main actor nothing per
/// window. Counted on `WorkMeter.shared` across the delivery alone:
/// the fixture pumps the read on the main thread, and a synchronous
/// test body admits no other main-thread AX in between.
@Suite("Arrival adoption (#2347)")
@MainActor
struct ArrivalAdoptionTests {
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
    final class Box {
        /// Main-actor AX calls made while a list applied.
        var applyCalls = 0
        var created: [ManagedWindow] = []
    }

    private let pid: pid_t = 900_828
    /// Far above any live WindowServer id, so the server snapshot
    /// `track` takes finds no window of the host's.
    private let tracked = WindowID(90_000_001)
    private let arrivals = [WindowID(90_000_002), WindowID(90_000_003)]
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.arrival", name: "Arrival")
    }

    private static var mainCalls: Int {
        WorkMeter.shared.snapshot(reset: false).counts.axMainCalls
    }

    /// A loop tracking one window of `pid` and listing two more,
    /// which the facts seam answers as standard windows.
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
        loop.activationPolicy = { _ in .regular }
        loop.onScreenNormalWindowIDs = { [:] }
        loop.appIsHidden = { _ in false }
        loop.frontmostPID = { nil }
        loop.processIdentity.runs = { _ in true }
        let ids = [tracked] + arrivals
        let elements = ids.indices.map {
            AXUIElementCreateApplication(902_001 + pid_t($0))
        }
        loop.axWindows = { _ in elements }
        loop.resolveWindowID = { element in
            elements.firstIndex { CFEqual($0, element) }.map { ids[$0] }
        }
        loop.readFullscreen = { _ in false }
        loop.offMain.readFacts = { _, layer in
            WindowFacts(
                role: kAXWindowRole,
                subrole: kAXStandardWindowSubrole,
                layer: layer
            ) { "Arrived" }
        }
        loop.shadows.traits = { _, id in
            id.map {
                WindowTraits(
                    id: $0,
                    hasTitlebarButton: true,
                    childCount: 3,
                    frame: .zero
                )
            }
        }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated {
                let before = Self.mainCalls
                work()
                box.applyCalls += Self.mainCalls - before
            }
        }
        loop.axReads.dispatchOverride = { _, work in
            MainActor.assumeIsolated { work() }
        }
        loop.onEvent = { event in
            if case .windowCreated(let window) = event {
                box.created.append(window)
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
        loop.elements[pid] = [tracked: elements[0]]
        return (loop, box)
    }

    @Test("an arrival costs the main actor no AX call")
    func arrivalAsksNothingOnMain() {
        let (loop, box) = makeLoop()
        loop.reconcileOffMain(pid: pid, app: ref)
        // Adopted from the read: the live title read answers "".
        #expect(box.created.map(\.id) == arrivals)
        #expect(box.created.allSatisfy { $0.title == "Arrived" })
        #expect(Set(loop.elements[pid]?.keys ?? [:].keys).count == 3)
        #expect(box.applyCalls == 0, "\(box.applyCalls) main-actor AX calls")
    }

    @Test("a switch batch's arrivals cost the main actor no AX call")
    func batchArrivalAsksNothingOnMain() {
        let (loop, box) = makeLoop()
        loop.reconcileOffMain(pid: pid, app: ref, coalesceTabs: false)
        #expect(box.created.map(\.id) == arrivals)
        #expect(box.applyCalls == 0, "\(box.applyCalls) main-actor AX calls")
    }

    /// The negative control: the same arrivals reconciled on the
    /// main actor ask the app, so the meter sees `track`'s reads
    /// in this fixture and a zero above measures something.
    @Test("a synchronous reconcile's arrivals do ask on main")
    func syncArrivalAsksOnMain() {
        let (loop, _) = makeLoop()
        let before = Self.mainCalls
        loop.reconcile(pid: pid, app: ref)
        #expect(Self.mainCalls - before >= arrivals.count)
    }
}
