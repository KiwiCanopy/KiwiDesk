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
        var hiddenEvents: [WindowID] = []
        var destroyed: [WindowID] = []
        var reads: [@Sendable () -> Void] = []
        var deliveries: [@MainActor @Sendable () -> Void] = []

        /// Runs every queued read, leaving its delivery queued.
        func read() {
            while !reads.isEmpty { reads.removeFirst()() }
        }

        func deliver() {
            while !deliveries.isEmpty { deliveries.removeFirst()() }
        }

        func drain() {
            while !reads.isEmpty || !deliveries.isEmpty {
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
            MainActor.assumeIsolated { box.hidden }
        }
        let element = AXUIElementCreateApplication(pid)
        loop.axWindows = { _ in
            MainActor.assumeIsolated { box.listReads += 1 }
            return [element]
        }
        let id = id
        loop.resolveWindowID = { _ in id }
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
        box.hidden = true
        loop.appHideChanged(pid: pid, ref: ref)
        #expect(box.listReads == 0, "hide read inline (#2027)")
        box.read()
        // The reading saw the app hidden; the unhide lands before
        // it applies, and only the live seam may say hidden.
        box.hidden = false
        loop.appHideChanged(pid: pid, ref: ref)
        box.drain()
        #expect(box.hiddenEvents.isEmpty)
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[id] != nil)
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
