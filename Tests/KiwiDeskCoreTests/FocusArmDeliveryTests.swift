import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **Every gate on a focus report is judged at DELIVERY, after
/// the off-main read** (#1088): the read's flight is where a
/// detach, a release, another app's activation or a focus
/// KiwiDesk commanded can land, and a gate read at receipt would
/// honor a report the flight made stale. The route itself is
/// `FocusArmRouteTests`'; the fixture is that suite's, per file.
@Suite("Focus arm delivery gates (#1088)")
@MainActor
struct FocusArmDeliveryTests {
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

    /// Captured read work, pumped by hand to model the app
    /// answering late.
    @MainActor
    private final class Box {
        var focused: [WindowID] = []
        var logs: [String] = []
        var listed: [WindowID] = []
        var work: [@Sendable () -> Void] = []
        var frame = CGRect(x: 10, y: 20, width: 800, height: 600)

        func drainOne() {
            guard !work.isEmpty else { return }
            work.removeFirst()()
        }
        var asked: [String] {
            logs.filter { $0.contains("AXFocusedWindowChanged asked") }
        }
    }

    private let pid: pid_t = 919_919
    private let other: pid_t = 818_818
    private let id = WindowID(11)
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.route", name: "Route")
    }
    private var element: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// A loop observing `pid` with window 11 tracked, its AX
    /// list answering the same window so the arm's reconcile
    /// keeps it, and the read captured for the test to pump.
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
        loop.lastActivePid = pid
        let dummy = element
        loop.axWindows = { _ in box.listed.map { _ in dummy } }
        loop.resolveWindowID = { _ in box.listed.first }
        loop.axReads.reader = { _ in
            MainActor.assumeIsolated { box.frame }
        }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        loop.axReads.dispatchOverride = { _, work in
            box.work.append(work)
        }
        loop.onEvent = { event in
            if case .windowFocused(let id) = event {
                box.focused.append(id)
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
        loop.elements[pid] = [id: dummy]
        box.listed = [id]
        return (loop, box)
    }

    private func report(_ loop: EventLoop) {
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
    }

    /// The #1322 gate is judged at DELIVERY: two apps' reads
    /// ride two queues, so a slow app's report can land after a
    /// fast app's activation, and honoring it then would park
    /// the focus on the app the user just left.
    @Test("Provenance is judged at delivery, not at receipt")
    func provenanceJudgedAtDelivery() {
        let (loop, box) = makeLoop()
        report(loop)
        loop.lastActivePid = other
        box.drainOne()
        #expect(box.focused.isEmpty, "reported \(box.focused)")
        #expect(
            box.logs.contains { $0.contains("app-internal") },
            "no drop line: \(box.logs)"
        )
    }

    @Test("A window released during the read is not reported")
    func releasedDuringFlightIsNotReported() {
        // A #913 hide drop or a sweep can land inside the
        // read's flight; an untracked focus would retile
        // focus-driven layouts around a window nobody manages
        // (#21).
        let (loop, box) = makeLoop()
        report(loop)
        loop.elements[pid] = [:]
        box.drainOne()
        #expect(box.focused.isEmpty, "reported \(box.focused)")
    }

    @Test("A read completing after detach delivers nothing")
    func detachedDuringFlightIsNotReported() {
        let (loop, box) = makeLoop()
        report(loop)
        loop.observers[pid] = nil
        box.drainOne()
        #expect(box.focused.isEmpty, "reported \(box.focused)")
    }

    /// A report received before a `focusWindow` and delivered
    /// after it describes the state the command superseded; the
    /// command's own echo follows. Honoring it dropped the
    /// scrolling raise and a Monocle flip's owed focus.
    @Test("A report older than a commanded focus is dropped")
    func staleAfterCommandedFocus() {
        let (loop, box) = makeLoop()
        report(loop)
        loop.lastCommandedFocus = .now
        box.drainOne()
        #expect(box.focused.isEmpty, "reported \(box.focused)")
        #expect(
            box.logs.contains { $0.contains("stale") },
            "no drop line: \(box.logs)"
        )
    }

    @Test("A command before the report leaves it standing")
    func commandBeforeReceiptStillDelivers() {
        let (loop, box) = makeLoop()
        loop.lastCommandedFocus = .now
        report(loop)
        box.drainOne()
        #expect(box.focused == [id])
    }
}
