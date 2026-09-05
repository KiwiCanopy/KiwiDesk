import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The fullscreen arm of the removal-distrust gate (#1272): a
/// native fullscreen transition orders the window out for a beat
/// on ENTER and EXIT while the compositor keeps it, and the sweep
/// read that as a close (the argument is accessibility.md's). This
/// suite holds the arm's shape: open on the loop's own last
/// fullscreen reading (EXIT) or the `fullscreenSpaceHosts` seam
/// (ENTER), refused census-blind on the #1157 episode's own
/// recheck budget (one ledger, one cap), refused outright while
/// the census shows it, never reading the switch grace, hide and
/// minimize exempt, the state AND the registration kept, and the
/// re-listed window's flag flip reported as a fullscreen CHANGE
/// in either direction, never a create.
///
/// Harness: `CarriedRemovalTests`' per-file copy. The destroy
/// NOTIFICATION's half of the arm is `FullscreenDestroyArmTests`'.
@MainActor
@Suite("Fullscreen-transition removal distrust (#1272)")
struct FullscreenRemovalTests {
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
        var fullscreenChanges: [(id: WindowID, isFullscreen: Bool)] = []
        var fullscreenRead = false
    }

    private let pid: pid_t = 909_930
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.fullscreen", name: "Fullscreen")
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
        loop.readFullscreen = { _ in box.fullscreenRead }
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
            case .windowFullscreenChanged(let id, let isFullscreen):
                box.fullscreenChanges.append(
                    (id: id, isFullscreen: isFullscreen)
                )
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

    /// An inert AX value for seeding `elements` directly; the
    /// fullscreen reading comes from the injected reader, never
    /// from it.
    private var dummyElement: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    private func fullscreenLines(_ box: Box) -> Int {
        box.logs.count {
            $0.hasPrefix("close distrust:")
                && $0.contains("native fullscreen transition")
        }
    }

    @Test("the exit beat is refused on the loop's last reading")
    func exitVanishIsRefused() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [
            WindowID(11): dummyElement,
            WindowID(12): dummyElement,
        ]
        // Listed in fullscreen since; now ordered out, and the
        // compositor already has it back on the Desktop, which
        // the seam does not report.
        loop.detectedFullscreen[WindowID(12)] = true
        loop.fullscreenSpaceHosts = { _ in false }
        box.listed = [WindowID(11)]
        box.census = [:]
        loop.lastDesktopChange = .distantPast
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        // State AND registration kept: the dead element stays
        // registered until the reconcile re-elements the id.
        #expect(loop.elements[pid]?[WindowID(12)] != nil)
        #expect(loop.removalDistrusted[WindowID(12)] == 1)
        #expect(loop.pendingRemovalRecheck.contains(pid))
        #expect(box.recheckFires == 1)
        #expect(fullscreenLines(box) == 1)
    }

    @Test("the enter beat is refused on the compositor's word")
    func enterVanishIsRefused() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        // Never read in fullscreen — the transition just began —
        // but the compositor already hosts it on the fullscreen
        // Space it minted.
        loop.detectedFullscreen[WindowID(12)] = false
        loop.fullscreenSpaceHosts = { $0 == WindowID(12) }
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = .distantPast
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[WindowID(12)] != nil)
        #expect(loop.removalDistrusted[WindowID(12)] == 1)
        #expect(fullscreenLines(box) == 1)
    }

    @Test("a window no arm expects is a close")
    func neitherArmIsAClose() {
        let (loop, box) = makeLoop()
        // Read as a plain window, and hosted on a user Desktop —
        // which a closed window also is for a while, so the seam
        // stays false and the close lands.
        loop.detectedFullscreen[WindowID(12)] = false
        loop.fullscreenSpaceHosts = { _ in false }
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = .distantPast
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.map(\.id) == [WindowID(12)])
        #expect(box.recheckFires == 0)
    }

    @Test("the arm never reads the switch grace")
    func armIgnoresTheSwitchGrace() {
        let (loop, box) = makeLoop()
        loop.detectedFullscreen[WindowID(12)] = true
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [:]
        // A fullscreen exit's sweep can run inside the grace —
        // the switch notification may land first — where the
        // census clause stands down; the arm must not.
        loop.lastDesktopChange = Date()
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        #expect(loop.removalDistrusted[WindowID(12)] == 1)
    }

    @Test("the census-blind budget is the episode's recheck budget")
    func blindRefusalRidesTheRecheckBudget() {
        let (loop, box) = makeLoop()
        loop.detectedFullscreen[WindowID(12)] = true
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [:]
        for arm in 1...EventLoop.removalRecheckCap {
            loop.reconcile(pid: pid, app: ref)
            #expect(box.destroyed.isEmpty)
            #expect(loop.removalDistrusted[WindowID(12)] == arm)
            #expect(box.recheckFires == arm)
            _ = loop.drainPendingRemovalRecheck()
        }
        // Past the cap: a window closed WHILE fullscreen takes its
        // ordinary removal, late by the budget.
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.map(\.id) == [WindowID(12)])
        #expect(loop.elements[pid]?[WindowID(12)] == nil)
        #expect(loop.removalDistrusted[WindowID(12)] == nil)
        #expect(loop.detectedFullscreen[WindowID(12)] == nil)
        #expect(fullscreenLines(box) == 1)
    }

    @Test("a census that shows the window refuses past the budget")
    func censusListedRefusesPastTheBudget() {
        let (loop, box) = makeLoop()
        loop.detectedFullscreen[WindowID(12)] = true
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        for _ in 0..<(EventLoop.removalRecheckCap + 2) {
            loop.reconcile(pid: pid, app: ref)
            _ = loop.drainPendingRemovalRecheck()
        }
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[WindowID(12)] != nil)
    }

    @Test("a re-listed window leaves fullscreen as a change, not a create")
    func relistedWindowReportsTheExit() {
        let (loop, box) = makeLoop()
        loop.detectedFullscreen[WindowID(12)] = true
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.removalDistrusted[WindowID(12)] = 1
        box.listed = [WindowID(12)]
        box.fullscreenRead = false
        loop.reconcile(pid: pid, app: ref)
        #expect(loop.removalDistrusted[WindowID(12)] == nil)
        #expect(box.destroyed.isEmpty)
        #expect(box.created.isEmpty)
        // The recheck re-reads the element out of fullscreen:
        // #670's exit path re-places the kept slot.
        #expect(box.fullscreenChanges.map(\.id) == [WindowID(12)])
        #expect(box.fullscreenChanges.map(\.isFullscreen) == [false])
        #expect(loop.detectedFullscreen[WindowID(12)] == false)
    }

    @Test("a re-listed window enters fullscreen as a change, not a create")
    func relistedWindowReportsTheEnter() {
        let (loop, box) = makeLoop()
        // Refused on the compositor's word; now listed again, in
        // fullscreen — the reading the EXIT arm will key on.
        loop.detectedFullscreen[WindowID(12)] = false
        loop.fullscreenSpaceHosts = { $0 == WindowID(12) }
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.removalDistrusted[WindowID(12)] = 1
        box.listed = [WindowID(12)]
        box.fullscreenRead = true
        loop.reconcile(pid: pid, app: ref)
        #expect(loop.removalDistrusted[WindowID(12)] == nil)
        #expect(box.destroyed.isEmpty)
        #expect(box.created.isEmpty)
        #expect(box.fullscreenChanges.map(\.id) == [WindowID(12)])
        #expect(box.fullscreenChanges.map(\.isFullscreen) == [true])
        #expect(loop.detectedFullscreen[WindowID(12)] == true)
    }

    @Test("a hide outranks the arm")
    func hideOutranksTheArm() {
        let (loop, box) = makeLoop()
        loop.detectedFullscreen[WindowID(12)] = true
        loop.fullscreenSpaceHosts = { _ in true }
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.hidden = true
        box.census = [pid: [WindowID(12)]]
        loop.reconcile(pid: pid, app: ref)
        #expect(box.censusReads == 0)
        #expect(box.hiddenEvents == [WindowID(12)])
        #expect(loop.removalDistrusted.isEmpty)
    }

    @Test("a minimized window is a minimize")
    func minimizeOutranksTheArm() {
        let (loop, box) = makeLoop()
        loop.detectedFullscreen[WindowID(12)] = true
        loop.fullscreenSpaceHosts = { _ in true }
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
}
