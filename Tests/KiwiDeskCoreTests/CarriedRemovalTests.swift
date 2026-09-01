import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The carried-window arm of the removal-distrust gate (#1145).
///
/// A window sticky reach carries is EXPECTED present on the
/// arriving Desktop, but for the switch transition's beat it is
/// on no reading: its AX element dies as it leaves the visible
/// Space and the census has not composited it yet. The pre-#1145
/// sweep read that as a close inside the switch grace — the
/// window lost its slot, scope and pin, and came back as new.
/// This suite holds the arm's shape: refused inside the grace on
/// a bounded census-blind budget, refused outright while the
/// census shows it, hide and minimize exempt, the state AND the
/// registration kept, and the same id re-elemented — never
/// re-created — when the window is listed again.
///
/// Harness: `RemovalDistrustTests`' per-file copy, plus an
/// own-pid loop for the notification arm (`NotificationWindowIDTests`'
/// shape — `handle` reads the activation policy off the live
/// process table, and only our own pid passes that gate).
@MainActor
@Suite("Carried-window removal distrust (#1145)")
struct CarriedRemovalTests {
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        var needsRegistrationRepair = false
        var observed: [AXUIElement] = []
        func observe(window: AXUIElement) { observed.append(window) }
        func repairRegistration() {}
        func invalidate() {}
    }

    @MainActor
    private final class Box {
        var hidden = false
        var listed: [WindowID] = []
        var cursor = 0
        var census: [pid_t: Set<WindowID>] = [:]
        var censusReads = 0
        var recheckFires = 0
        var logs: [String] = []
        var hiddenEvents: [WindowID] = []
        var destroyed: [(id: WindowID, wasMinimized: Bool)] = []
        var created: [WindowID] = []
    }

    private let pid: pid_t = 909_920
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.carried", name: "Carried")
    }

    /// Wires every seam; `attach` is the caller's, so the own-pid
    /// arm can register its observer directly instead.
    private func wire(_ loop: EventLoop, _ box: Box) {
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
        loop.onScreenNormalWindowIDs = {
            box.censusReads += 1
            return box.census
        }
        loop.onRemovalDistrust = { box.recheckFires += 1 }
        loop.axWindows = { _ in
            box.cursor = 0
            return box.listed.map { _ in self.dummyElement }
        }
        loop.resolveWindowID = { _ in
            defer { box.cursor += 1 }
            guard box.cursor < box.listed.count else { return nil }
            return box.listed[box.cursor]
        }
        loop.appIsHidden = { _ in box.hidden }
        loop.onEvent = { event in
            switch event {
            case .windowDestroyed(let id, let wasMinimized):
                box.destroyed.append(
                    (id: id, wasMinimized: wasMinimized)
                )
            case .windowHidden(let id):
                box.hiddenEvents.append(id)
            case .windowCreated(let window):
                box.created.append(window.id)
            default:
                break
            }
        }
    }

    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        return (loop, box)
    }

    /// An inert AX value for seeding `elements` directly.
    private var dummyElement: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// A second, distinct inert value — the window's element
    /// reborn on the arriving Desktop.
    private var freshElement: AXUIElement {
        AXUIElementCreateApplication(pid + 1)
    }

    private func carriedLines(_ box: Box) -> Int {
        box.logs.count {
            $0.hasPrefix("close distrust:")
                && $0.contains("carried across Desktops")
        }
    }

    @Test("a carried vanish inside the switch grace is refused")
    func carriedVanishInsideGraceIsRefused() {
        let (loop, box) = makeLoop()
        loop.carriedRemoval.carried = { [WindowID(12)] }
        loop.elements[pid] = [
            WindowID(11): dummyElement,
            WindowID(12): dummyElement,
        ]
        box.listed = [WindowID(11)]
        box.census = [:]
        loop.lastDesktopChange = Date()
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        // State AND registration kept: the dead element stays
        // registered until the reconcile re-elements the id.
        #expect(loop.elements[pid]?[WindowID(12)] != nil)
        #expect(loop.carriedRemoval.arms[WindowID(12)] == 1)
        // The refusal rides the distrust's own convergence.
        #expect(loop.pendingRemovalRecheck.contains(pid))
        #expect(box.recheckFires == 1)
        #expect(carriedLines(box) == 1)
    }

    @Test("an uncarried vanish inside the grace keeps the old gate")
    func uncarriedVanishInsideGraceIsRemoved() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        loop.lastDesktopChange = Date()
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.map(\.id) == [WindowID(12)])
        #expect(box.censusReads == 0)
    }

    @Test("the census-blind budget is bounded, then a close is a close")
    func armsBoundTheBlindRefusal() {
        let (loop, box) = makeLoop()
        loop.carriedRemoval.carried = { [WindowID(12)] }
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = Date()
        for arm in 1...CarriedRemovalGate.armCap {
            loop.reconcile(pid: pid, app: ref)
            #expect(box.destroyed.isEmpty)
            #expect(loop.carriedRemoval.arms[WindowID(12)] == arm)
        }
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.map(\.id) == [WindowID(12)])
        #expect(loop.elements[pid]?[WindowID(12)] == nil)
        #expect(loop.carriedRemoval.arms[WindowID(12)] == nil)
        // One episode, one line.
        #expect(carriedLines(box) == 1)
    }

    @Test("a census that shows the window refuses without spending")
    func censusListedRefusesWithoutSpending() {
        let (loop, box) = makeLoop()
        loop.carriedRemoval.carried = { [WindowID(12)] }
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        loop.lastDesktopChange = Date()
        for _ in 0..<(CarriedRemovalGate.armCap + 2) {
            loop.reconcile(pid: pid, app: ref)
        }
        #expect(box.destroyed.isEmpty)
        #expect(loop.carriedRemoval.arms[WindowID(12)] == nil)
    }

    @Test("a window back in the list resets its arms")
    func relistedWindowResetsArms() {
        let (loop, box) = makeLoop()
        loop.carriedRemoval.carried = { [WindowID(12)] }
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.carriedRemoval.arms[WindowID(12)] = 2
        box.listed = [WindowID(12)]
        loop.reconcile(pid: pid, app: ref)
        #expect(loop.carriedRemoval.arms[WindowID(12)] == nil)
        #expect(box.destroyed.isEmpty)
    }

    @Test("a hide outranks the carry")
    func hideOutranksTheCarry() {
        let (loop, box) = makeLoop()
        loop.carriedRemoval.carried = { [WindowID(11), WindowID(12)] }
        loop.elements[pid] = [
            WindowID(11): dummyElement,
            WindowID(12): dummyElement,
        ]
        box.hidden = true
        box.census = [pid: [WindowID(11), WindowID(12)]]
        loop.reconcile(pid: pid, app: ref)
        #expect(box.censusReads == 0)
        #expect(
            box.hiddenEvents.sorted { $0.raw < $1.raw }
                == [WindowID(11), WindowID(12)]
        )
        #expect(loop.carriedRemoval.arms.isEmpty)
    }

    @Test("a minimized carried window is a minimize")
    func minimizeOutranksTheCarry() {
        let (loop, box) = makeLoop()
        loop.carriedRemoval.carried = { [WindowID(12)] }
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.census = [:]
        loop.reconcileTabsAndSweep(
            pid: pid,
            app: ref,
            appeared: [],
            live: [],
            minimized: [WindowID(12)],
            coalesceTabs: false
        )
        #expect(box.censusReads == 0)
        #expect(box.destroyed.map(\.wasMinimized) == [true])
    }

    @Test("stop forgets the arms")
    func stopForgetsTheArms() {
        let (loop, _) = makeLoop()
        loop.carriedRemoval.arms[WindowID(12)] = 2
        loop.stop()
        #expect(loop.carriedRemoval.arms.isEmpty)
    }

    /// The own-pid loop the notification arm needs: `handle`
    /// reads the policy off the live process table, which only
    /// our own pid answers for.
    private func makeOwnLoop() -> (loop: EventLoop, box: Box, pid: pid_t) {
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        let own = pid_t(getpid())
        loop.observers[own] = FakeObserver()
        return (loop, box, own)
    }

    @Test("a carried window's destroyed element defers to the sweep")
    func destroyedNotificationDefersToTheSweep() {
        let (loop, box, own) = makeOwnLoop()
        let element = dummyElement
        loop.carriedRemoval.carried = { [WindowID(12)] }
        loop.elements[own] = [WindowID(12): element]
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = Date()
        loop.handle(
            kAXUIElementDestroyedNotification,
            element,
            pid: own,
            app: AppRef(bundleID: nil, name: "Own")
        )
        // No eager destroy: the sweep the arm ran instead refused
        // the carried vanish and kept the registration.
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[own]?[WindowID(12)] != nil)
        #expect(loop.carriedRemoval.arms[WindowID(12)] == 1)
    }

    @Test("a re-listed window is re-elemented, never re-created")
    func relistedWindowIsReElemented() {
        let (loop, box) = makeLoop()
        let dead = dummyElement
        let reborn = freshElement
        #expect(!CFEqual(dead, reborn))
        loop.elements[pid] = [WindowID(12): dead]
        loop.axWindows = { _ in [reborn] }
        loop.resolveWindowID = { _ in WindowID(12) }
        let observer = loop.observers[pid] as? FakeObserver
        loop.reconcile(pid: pid, app: ref)
        // Same id, fresh element, observed anew — and no create,
        // which would re-fold a window state never lost.
        #expect(
            loop.elements[pid]?[WindowID(12)].map {
                CFEqual($0, reborn)
            } == true
        )
        #expect(observer?.observed.count == 1)
        #expect(box.created.isEmpty)
        #expect(box.destroyed.isEmpty)
    }
}
