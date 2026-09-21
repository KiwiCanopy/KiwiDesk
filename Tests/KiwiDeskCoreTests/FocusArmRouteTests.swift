import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **The focus arm resolves from the tracked map and reads the
/// element off the main actor** (#1088) — the #1084 route the
/// move/resize arms took, with #618's off-main read standing in
/// for the liveness the blocking ask gave for free.
///
/// Driven through the real branch, `handleFocusedWindowChanged`,
/// on stubbed seams. The ask is observed through its own log
/// line rather than a call count, because the reconcile ahead
/// of the arm asks for every listed window through the same
/// seam and would count against it.
@Suite("Focus arm route (#1088)")
@MainActor
struct FocusArmRouteTests {
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

    @Test("A tracked window is resolved without asking the app")
    func trackedWindowNeverAsks() {
        let (loop, box) = makeLoop()
        report(loop)
        box.drainOne()
        #expect(box.focused == [id])
        // The whole fix: no round-trip for a window we track.
        #expect(box.asked.isEmpty, "asked: \(box.asked)")
    }

    @Test("The read is scheduled, never performed inline")
    func readIsScheduledNotInline() {
        // The wire (#618's shape): the report lands after the
        // pump runs, with the tracked frame refreshed, and the
        // proof line names the off-main read.
        let (loop, box) = makeLoop()
        loop.trackedFrames[id] = .zero
        report(loop)
        #expect(box.focused.isEmpty, "reported inline")
        #expect(box.work.count == 1)
        box.drainOne()
        #expect(box.focused == [id])
        #expect(loop.trackedFrames[id] == box.frame)
        #expect(
            box.logs.contains { $0.contains("liveness read") },
            "no proof line: \(box.logs)"
        )
    }

    @Test("A dead element's zero frame is dropped at delivery")
    func deadElementIsDroppedAtDelivery() {
        // The liveness the map lost (#1084 review): asking
        // filtered a destroyed element for free, and the map
        // still names one whose entry the sweep has not
        // reached. `AXHelper.frame` answers `.zero` for it, and
        // no on-screen window has that frame.
        let (loop, box) = makeLoop()
        box.frame = .zero
        report(loop)
        box.drainOne()
        #expect(box.focused.isEmpty, "reported \(box.focused)")
        #expect(
            box.logs.contains { $0.contains("dead at delivery") },
            "no drop line: \(box.logs)"
        )
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

    @Test("An ambiguous element asks rather than guessing")
    func ambiguousElementAsks() {
        // Two ids, one element — the shape a re-key that failed
        // to remove its old key would leave behind. The list
        // answers both ids so the reconcile keeps both.
        let (loop, box) = makeLoop()
        let twin = WindowID(12)
        loop.elements[pid] = [id: element, twin: element]
        box.listed = [id, twin]
        nonisolated(unsafe) var answers = [id, twin, id]
        loop.resolveWindowID = { _ in
            MainActor.assumeIsolated { answers.removeFirst() }
        }
        report(loop)
        #expect(
            box.asked.contains { $0.contains("(ambiguous)") },
            "no ask: \(box.logs)"
        )
        box.drainOne()
        #expect(box.focused == [id])
    }

    @Test("An untracked window still asks, and classifies")
    func untrackedStillAsksAndClassifies() {
        // The map is not a wall: the #21 classification needs
        // the panel's id, and the ask is the one reader that
        // has it. No read is scheduled for it.
        let (loop, box) = makeLoop()
        loop.elements[pid] = [:]
        box.listed = []
        loop.resolveWindowID = { _ in WindowID(77) }
        report(loop)
        #expect(
            box.asked.contains { $0.contains("(untracked) → w77") },
            "no ask: \(box.logs)"
        )
        #expect(
            box.logs.contains { $0.contains("untracked w77") },
            "the untracked path did not run: \(box.logs)"
        )
        #expect(box.work.isEmpty)
        #expect(box.focused.isEmpty)
    }
}
