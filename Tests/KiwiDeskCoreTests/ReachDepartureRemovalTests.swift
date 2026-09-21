import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The reach-departure arm of the removal-distrust gate (#1215).
///
/// On a GESTURE Desktop switch a native app's element dies
/// 30–130 ms BEFORE the switch handler that would carry a
/// reach-enabled sticky window, so the pre-#1215 fold removed the
/// window from state and the carry found nothing to move: the
/// window stayed behind (owner's swipe, TextEdit, 2026-09-21, 2
/// of 2). The on-screen census is a coin flip at that instant;
/// the compositor's per-window host is not. This suite holds the
/// arm's shape on BOTH halves — the sweep and the destroy
/// notification's deferral: a vanish the `reachAwaitsCarry` seam
/// expects is refused census-blind on the #1157 episode's own
/// recheck budget (one ledger, one cap), refused outright while
/// the census shows it, never read against the switch grace,
/// hide and minimize exempt, the state AND the registration kept.
/// A window the seam does not name is a close like any other.
///
/// Harness: `CarriedRemovalTests`' per-file copy, on our OWN pid
/// for the notification half (`handle` reads the activation policy
/// off the live process table, which only our pid answers for).
@MainActor
@Suite("Reach-departure removal distrust (#1215)")
struct ReachDepartureRemovalTests {
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

    private let pid: pid_t = 909_921
    private let window = WindowID(12)
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.reach", name: "Reach")
    }

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

    /// The sweep's loop: attached, the vanished window registered,
    /// nothing in flight and no fullscreen reading — only the seam
    /// under test decides.
    private func makeLoop(awaits: Bool) -> (loop: EventLoop, box: Box) {
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
        loop.carriedWindows = { [] }
        loop.fullscreenSpaceHosts = { _ in false }
        loop.reachAwaitsCarry = { awaits && $0 == self.window }
        loop.elements[pid] = [window: dummyElement]
        box.listed = []
        box.census = [:]
        // Outside the switch grace: the handler has not run, so
        // nothing has stamped the switch yet — the measured order.
        loop.lastDesktopChange = .distantPast
        return (loop, box)
    }

    /// An inert AX value for seeding `elements` directly.
    private var dummyElement: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    private func awaitingLines(_ box: Box) -> Int {
        box.logs.count {
            $0.hasPrefix("close distrust:")
                && $0.contains("awaiting the Desktop-reach carry")
        }
    }

    @Test("a vanish the carry owes a move is refused census-blind")
    func awaitedVanishIsRefused() {
        let (loop, box) = makeLoop(awaits: true)
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        // State AND registration kept: the dead element stays
        // registered until the reconcile re-elements the id.
        #expect(loop.elements[pid]?[window] != nil)
        #expect(loop.removalDistrusted[window] == 1)
        #expect(loop.pendingRemovalRecheck.contains(pid))
        #expect(box.recheckFires == 1)
        #expect(awaitingLines(box) == 1)
    }

    @Test("a window the seam does not name is a close")
    func unawaitedVanishIsAClose() {
        let (loop, box) = makeLoop(awaits: false)
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.map(\.id) == [window])
        #expect(loop.elements[pid]?[window] == nil)
        #expect(box.recheckFires == 0)
    }

    @Test("the arm never reads the switch grace, and joins it closed")
    func armIgnoresTheSwitchGrace() {
        // Open inside the grace: refused on the seam alone.
        let (open, openBox) = makeLoop(awaits: true)
        open.lastDesktopChange = Date()
        open.reconcile(pid: pid, app: ref)
        #expect(openBox.destroyed.isEmpty)
        #expect(open.removalDistrusted[window] == 1)
        // Closed inside the grace: the census clause stands down
        // and no arm refuses — a vanish nothing expects is removed.
        let (closed, closedBox) = makeLoop(awaits: false)
        closed.lastDesktopChange = Date()
        closedBox.census = [pid: [window]]
        closed.reconcile(pid: pid, app: ref)
        #expect(closedBox.destroyed.map(\.id) == [window])
        #expect(closedBox.censusReads == 0)
    }

    @Test("the census-blind budget is the episode's recheck budget")
    func blindRefusalRidesTheRecheckBudget() {
        let (loop, box) = makeLoop(awaits: true)
        for arm in 1...EventLoop.removalRecheckCap {
            loop.reconcile(pid: pid, app: ref)
            #expect(box.destroyed.isEmpty)
            #expect(loop.removalDistrusted[window] == arm)
            #expect(box.recheckFires == arm)
            _ = loop.drainPendingRemovalRecheck()
        }
        // Past the cap the carry never came: the departure lands.
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.map(\.id) == [window])
        #expect(loop.elements[pid]?[window] == nil)
        #expect(loop.removalDistrusted[window] == nil)
        #expect(awaitingLines(box) == 1)
    }

    @Test("a census that shows the window refuses past the budget")
    func censusListedRefusesPastTheBudget() {
        let (loop, box) = makeLoop(awaits: true)
        box.census = [pid: [window]]
        for _ in 0..<(EventLoop.removalRecheckCap + 2) {
            loop.reconcile(pid: pid, app: ref)
            _ = loop.drainPendingRemovalRecheck()
        }
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[window] != nil)
        // #1157's own refusal, not this arm's line.
        #expect(awaitingLines(box) == 0)
    }

    @Test("a hide outranks the arm")
    func hideOutranksTheArm() {
        let (loop, box) = makeLoop(awaits: true)
        box.hidden = true
        loop.reconcile(pid: pid, app: ref)
        #expect(box.censusReads == 0)
        #expect(box.hiddenEvents == [window])
        #expect(loop.removalDistrusted.isEmpty)
    }

    @Test("a minimized window is a minimize")
    func minimizeOutranksTheArm() {
        let (loop, box) = makeLoop(awaits: true)
        loop.reconcileTabsAndSweep(
            pid: pid,
            app: ref,
            appeared: [],
            live: [],
            minimized: [window],
            coalesceTabs: false
        )
        #expect(box.censusReads == 0)
        #expect(box.destroyed.map(\.wasMinimized) == [true])
    }

    // MARK: - The destroy notification's half

    /// The own-pid loop the notification arm needs.
    private func makeOwnLoop(
        awaits: Bool
    ) -> (loop: EventLoop, box: Box, pid: pid_t) {
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        let own = pid_t(getpid())
        loop.observers[own] = FakeObserver()
        loop.carriedWindows = { [] }
        loop.fullscreenSpaceHosts = { _ in false }
        loop.reachAwaitsCarry = { awaits && $0 == self.window }
        loop.lastDesktopChange = .distantPast
        return (loop, box, own)
    }

    @Test("an awaited window's destroyed element defers to the sweep")
    func destroyedNotificationDefersToTheSweep() {
        let (loop, box, own) = makeOwnLoop(awaits: true)
        let element = dummyElement
        loop.elements[own] = [window: element]
        loop.handle(
            kAXUIElementDestroyedNotification,
            element,
            pid: own,
            app: AppRef(bundleID: nil, name: "Own")
        )
        // No eager destroy: the sweep the arm ran instead refused
        // the vanish and kept the registration.
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[own]?[window] != nil)
        #expect(loop.removalDistrusted[window] == 1)
    }

    @Test("an unawaited window's destroyed element is eager")
    func destroyedNotificationIsEagerWhenClosed() {
        let (loop, box, own) = makeOwnLoop(awaits: false)
        let element = dummyElement
        loop.elements[own] = [window: element]
        loop.handle(
            kAXUIElementDestroyedNotification,
            element,
            pid: own,
            app: AppRef(bundleID: nil, name: "Own")
        )
        #expect(box.destroyed.map(\.id) == [window])
        #expect(loop.elements[own]?[window] == nil)
        // The eager arm releases the element before its reconcile,
        // so the sweep finds nothing vanished and reads no census.
        #expect(box.censusReads == 0)
    }
}
