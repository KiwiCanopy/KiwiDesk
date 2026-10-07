import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **A hide, an unhide and the #1157 distrust follow-up read the
/// window list OFF the main actor** (#2027): the follow-up fires
/// because an app just answered badly, which is when it is slow.
/// The transient re-track's half is `AdoptionHealScheduleTests`'.
///
/// The read and its delivery are captured apart, so a test can
/// land an event between them — `ReconcileOffMainTests`' fixture
/// shape.
@Suite("Hide and recheck reconcile off main (#2027)")
@MainActor
struct ReconcileOffMainRecheckTests {
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
        var listReads = 0
        var hidden = false
        /// What the off-main read sees, where it differs from the
        /// live seam's `hidden`.
        var readHidden: Bool?
        var reading = false
        var hiddenEvents: [WindowID] = []
        var destroyed: [WindowID] = []
        var focused: [WindowID] = []
        /// Focus commands asked through `onUnhideFocus`.
        var commanded: [WindowID] = []
        var reads: [@Sendable () -> Void] = []
        var deliveries: [@MainActor @Sendable () -> Void] = []

        /// Runs every queued read, leaving its delivery queued.
        func read() {
            reading = true
            while !reads.isEmpty { reads.removeFirst()() }
            reading = false
        }

        var idle: Bool { reads.isEmpty && deliveries.isEmpty }

        func deliver() {
            while !deliveries.isEmpty { deliveries.removeFirst()() }
        }

        /// Bounded, so a read chain that never ends reds a test
        /// instead of hanging it.
        func drain() {
            for _ in 0..<20 where !idle {
                read()
                deliver()
            }
        }
    }

    private let pid: pid_t = 727_727
    private let id = WindowID(31)
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.recheck", name: "Recheck")
    }

    /// Wires `loop` to `box`, observing `pid` with window 31
    /// tracked and listed.
    private func wire(_ loop: EventLoop, _ box: Box) {
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
        loop.frontmostPID = { nil }
        loop.appIsHidden = { _ in
            MainActor.assumeIsolated {
                box.reading ? box.readHidden ?? box.hidden : box.hidden
            }
        }
        let element = AXUIElementCreateApplication(pid)
        loop.axWindows = { _ in
            MainActor.assumeIsolated { box.listReads += 1 }
            return [element]
        }
        let id = id
        loop.resolveWindowID = { _ in id }
        loop.shadows.focusedWindow = { _ in id }
        loop.onUnhideFocus = { box.commanded.append($0) }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated { box.deliveries.append(work) }
        }
        loop.axReads.dispatchOverride = { _, work in
            box.reads.append(work)
        }
        loop.onEvent = { event in
            switch event {
            case .windowHidden(let id): box.hiddenEvents.append(id)
            case .windowDestroyed(let id, _): box.destroyed.append(id)
            case .windowFocused(let id): box.focused.append(id)
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
        loop.elements[pid] = [id: element]
    }

    @Test("an unhide landing mid-read keeps the windows")
    func unhideDuringTheHideReadWins() {
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        var settled = 0
        box.hidden = true
        // The arm's own request, with what waits on it (#1795).
        loop.reconcileOffMain(pid: pid, app: ref) { settled += 1 }
        #expect(box.listReads == 0, "hide read inline (#2027)")
        box.read()
        #expect(box.listReads == 0, "a hidden app's list was read")
        // The reading saw the app hidden; the unhide lands before
        // it applies, and only the live seam may say hidden.
        box.hidden = false
        loop.appHideChanged(pid: pid, ref: ref)
        box.deliver()
        #expect(settled == 0, "ran on the skipped list")
        box.drain()
        #expect(box.idle)
        #expect(settled == 1)
        #expect(box.hiddenEvents.isEmpty)
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[id] != nil)
        #expect(box.listReads == 1)
    }

    @Test("a skipped list meeting an unhide sweeps nothing")
    func skippedListOwesAListingRead() {
        // No unhide request parks behind the read here, so the
        // apply itself owes the read that lists, and what waited
        // on the skipped one waits for it.
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        var settled = 0
        // The off-main read keeps answering hidden, so only the
        // forced listing read ends the chain.
        box.readHidden = true
        loop.reconcileOffMain(pid: pid, app: ref) { settled += 1 }
        box.read()
        box.deliver()
        #expect(box.destroyed.isEmpty, "an empty skip was swept")
        #expect(box.hiddenEvents.isEmpty)
        #expect(settled == 0, "ran before a listing read")
        #expect(!box.reads.isEmpty, "no listing read owed")
        box.drain()
        #expect(box.idle, "the read chain did not end")
        #expect(box.listReads == 1)
        #expect(settled == 1)
        #expect(loop.elements[pid]?[id] != nil)
        #expect(box.destroyed.isEmpty)
    }

    /// Hidden with window 31 dropped, then a Dock click: the
    /// activation's reads settle while the app still reads hidden,
    /// and the unhide follows it (device, 2026-10-07).
    private func activateHidden(_ loop: EventLoop, _ box: Box) {
        box.hidden = true
        loop.appHideChanged(pid: pid, ref: ref)
        box.drain()
        #expect(loop.elements[pid]?[id] == nil)
        loop.appActivated(
            RunningApp(pid: pid, activationPolicy: .regular, ref: ref),
            launchedAt: nil
        )
        box.drain()
        #expect(box.focused.isEmpty)
        box.hidden = false
        loop.appHideChanged(pid: pid, ref: ref)
        // `track` needs live AX, so the window the unhide's read
        // lists is seeded as its adoption would file it.
        box.read()
        loop.elements[pid] = [id: AXUIElementCreateApplication(pid)]
    }

    /// A focus COMMAND, not the app's report: the unhide's retile
    /// just placed the window, so a report would be bounced
    /// (#1161, device 2026-10-07).
    @Test("an unhide of the active app commands what it adopts")
    func unhideFocusesTheActiveApp() {
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        activateHidden(loop, box)
        box.drain()
        #expect(box.idle)
        #expect(box.commanded == [id], "the activation focus was lost")
        #expect(box.focused.isEmpty, "reported, not commanded")
    }

    @Test("another app activated meanwhile keeps its focus")
    func unhideYieldsToANewerActivation() {
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        activateHidden(loop, box)
        loop.lastActivePid = pid + 1
        box.drain()
        #expect(box.idle)
        #expect(box.commanded.isEmpty)
        #expect(box.focused.isEmpty)
    }

    @Test("a hide landing mid-read is applied by the read after")
    func hideDuringAReadDropsOnTheNext() {
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        loop.reconcileOffMain(pid: pid, app: ref)
        box.read()
        box.hidden = true
        loop.appHideChanged(pid: pid, ref: ref)
        box.deliver()
        #expect(box.hiddenEvents.isEmpty, "a stale read hid it")
        box.drain()
        #expect(box.hiddenEvents == [id])
        #expect(box.destroyed.isEmpty)
    }

    @Test("the distrust follow-up reads off main, unmerged")
    func removalRecheckReadsOffMain() async {
        let core = makeTestCore()
        let box = Box()
        let loop = core.eventLoop
        wire(loop, box)
        defer {
            core.deferred.cancelAll()
            loop.stop()
        }
        core.timings.transientRetrackDelay = .milliseconds(1)
        // A read already in flight parks the follow-up as its
        // debt, which shows the shape it asked for.
        loop.reconcileOffMain(pid: pid, app: ref)
        loop.refuseRemoval(id, pid: pid, app: ref)
        await core.deferred.task(for: .removalRecheck)?.value
        #expect(loop.drainPendingRemovalRecheck().isEmpty)
        #expect(box.listReads == 0, "list read inline (#2027)")
        #expect(loop.offMain.next[pid]?.coalesceTabs == false)
        box.drain()
        #expect(box.listReads == 2)
        #expect(loop.offMain.next[pid] == nil)
    }
}
