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

    /// How many of the fixture's windows the app still lists, and
    /// their WindowServer layers; read on the list read's thread.
    final class Listing: @unchecked Sendable {
        var count = 3
        var layers: [WindowID: Int] = [:]
        /// Windows whose traits read as a shell: no title-bar
        /// button and no child (#1785).
        var shells: Set<WindowID> = []
    }

    @MainActor
    final class Box {
        /// Main-actor AX calls made while a list applied.
        var applyCalls = 0
        /// Per-window seams asked while a list applied: their
        /// fakes answer outside `WorkMeter`.
        var applySeams: [String] = []
        var applying = false
        /// Deliveries held back, where a test lands them by hand.
        var held: [() -> Void]?
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
    private func makeLoop() -> (
        loop: EventLoop,
        box: Box,
        elements: [AXUIElement],
        listing: Listing
    ) {
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
        let listing = Listing()
        loop.offMain.readLayers = { _ in listing.layers }
        loop.axWindows = { _ in Array(elements.prefix(listing.count)) }
        loop.resolveWindowID = { element in
            elements.firstIndex { CFEqual($0, element) }.map { ids[$0] }
        }
        loop.readFullscreen = { _ in
            MainActor.assumeIsolated {
                if box.applying { box.applySeams.append("fullscreen") }
            }
            return false
        }
        loop.offMain.readFacts = { _, layer in
            WindowFacts(
                role: kAXWindowRole,
                subrole: kAXStandardWindowSubrole,
                layer: layer
            ) { "Arrived" }
        }
        loop.shadows.traits = { element, known in
            // A sibling read names no id.
            let id =
                known
                ?? elements.firstIndex { CFEqual($0, element) }.map {
                    ids[$0]
                }
            MainActor.assumeIsolated {
                if box.applying { box.applySeams.append("traits") }
            }
            return id.map {
                let shell = listing.shells.contains($0)
                return WindowTraits(
                    id: $0,
                    hasTitlebarButton: !shell,
                    childCount: shell ? 0 : 3,
                    frame: .zero
                )
            }
        }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated {
                if box.held != nil {
                    box.held?.append(work)
                    return
                }
                let before = Self.mainCalls
                box.applying = true
                work()
                box.applying = false
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
        return (loop, box, elements, listing)
    }

    @Test("an arrival costs the main actor no AX call")
    func arrivalAsksNothingOnMain() {
        let (loop, box, _, _) = makeLoop()
        loop.reconcileOffMain(pid: pid, app: ref)
        // Adopted from the read: the live title read answers "".
        #expect(box.created.map(\.id) == arrivals)
        #expect(box.created.allSatisfy { $0.title == "Arrived" })
        #expect(Set(loop.elements[pid]?.keys ?? [:].keys).count == 3)
        #expect(box.applyCalls == 0, "\(box.applyCalls) main-actor AX calls")
        #expect(box.applySeams.isEmpty, "\(box.applySeams)")
    }

    /// The bulk shape a Desktop switch's fold applies: no tab
    /// match, so `track` alone consumes the reading.
    @Test("a bulk-shaped read's arrivals cost the main actor no AX call")
    func bulkArrivalAsksNothingOnMain() {
        let (loop, box, _, _) = makeLoop()
        loop.reconcileOffMain(pid: pid, app: ref, coalesceTabs: false)
        #expect(box.created.map(\.id) == arrivals)
        #expect(box.applyCalls == 0, "\(box.applyCalls) main-actor AX calls")
        #expect(box.applySeams.isEmpty, "\(box.applySeams)")
    }

    /// The negative control: the same arrivals reconciled on the
    /// main actor ask the app, so the meter sees `track`'s reads
    /// in this fixture and a zero above measures something.
    @Test("a synchronous reconcile's arrivals do ask on main")
    func syncArrivalAsksOnMain() {
        let (loop, _, _, _) = makeLoop()
        let before = Self.mainCalls
        loop.reconcile(pid: pid, app: ref)
        #expect(Self.mainCalls - before >= arrivals.count)
    }

    /// Lands a read that listed every window after `depart` ended
    /// the third, which the app then stops listing.
    private func departDuringTheRead(
        _ depart: (EventLoop, [AXUIElement]) -> Void
    ) throws -> [WindowID] {
        let (loop, box, elements, listing) = makeLoop()
        box.held = []
        loop.reconcileOffMain(pid: pid, app: ref)
        let delivery = box.held ?? []
        try #require(delivery.count == 1)
        depart(loop, elements)
        // Gone from the live list too, so the read the departure
        // owes answers for it as well.
        listing.count = 2
        box.held = nil
        for work in delivery { work() }
        return box.created.map(\.id)
    }

    /// The reading predates the departure: `track` reads the
    /// window live, which the fabricated element refuses.
    @Test("a window minimized during the read is not adopted from it")
    func minimizedDuringTheReadIsNotAdopted() throws {
        let created = try departDuringTheRead { loop, elements in
            loop.handle(
                kAXWindowMiniaturizedNotification,
                elements[2],
                pid: pid,
                app: ref
            )
        }
        #expect(created == [arrivals[0]])
    }

    /// A close reaches the loop only for a window observed at
    /// `track`: one tracked during the read, released by its close
    /// and listed by the reading again.
    @Test("a window tracked and closed during the read is not adopted")
    func closedDuringTheReadIsNotAdopted() throws {
        let created = try departDuringTheRead { loop, elements in
            // Filed as the create arm would have.
            loop.elements[pid]?[arrivals[1]] = elements[2]
            loop.handle(
                kAXUIElementDestroyedNotification,
                elements[2],
                pid: pid,
                app: ref
            )
        }
        #expect(created == [arrivals[0]])
    }

    /// A window untracked through the read reports no AX close;
    /// WindowServer's destroy names it by id.
    @Test("a window WindowServer destroys during the read is not adopted")
    func serverDestroyedDuringTheReadIsNotAdopted() throws {
        let created = try departDuringTheRead { loop, _ in
            loop.windowServerDestroyed(arrivals[1])
        }
        #expect(created == [arrivals[0]])
    }

    /// Detection judged the layer the list read saw; where the
    /// server reports another at `track`, the window is judged live,
    /// which asks the app on the main actor.
    @Test("a changed layer judges the arrival live")
    func changedLayerReadsLive() {
        let (loop, box, _, listing) = makeLoop()
        // The server snapshot reports no layer for these ids.
        for id in arrivals { listing.layers[id] = 0 }
        loop.reconcileOffMain(pid: pid, app: ref)
        #expect(box.applyCalls >= arrivals.count)
    }

    /// The shadow rule judges an arrival too, on the traits the
    /// read took: a shell beside a buttoned sibling never tiles.
    @Test("an arrival that reads as a shadow is not adopted")
    func shadowArrivalIsRefused() {
        let (loop, box, _, listing) = makeLoop()
        listing.shells = [arrivals[1]]
        loop.reconcileOffMain(pid: pid, app: ref)
        #expect(box.created.map(\.id) == [arrivals[0]])
        #expect(loop.shadows.holds(arrivals[1], pid: pid))
    }
}
