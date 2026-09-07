import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// **A focus report from the accessibility channel counts only
/// from the app macOS activated last** (#1322).
///
/// A non-activating panel — the Claude desktop app's overlay, an
/// `AXSystemDialog` — empties its app's focused window while it
/// is up and flips it back to the main window on close, without
/// the app ever becoming frontmost (measured on the device:
/// `frontmostApplication` stayed Zen / Telegram through every
/// cycle). KiwiDesk honored that flip as a focus change, moved
/// its anchor onto a window that did not have the system focus,
/// and every focus chord after it was refused until a click.
///
/// Driven through the real branch, `handleFocusedWindowChanged`,
/// with the reconcile it opens on stubbed seams; a report from an
/// app that does activate is the activation channel's to make.
@Suite("Focus report provenance (#1322)")
@MainActor
struct FocusReportProvenanceTests {
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
        var focused: [WindowID] = []
        var logs: [String] = []
        var listed: [WindowID] = []
    }

    private let pid: pid_t = 909_909
    private let other: pid_t = 808_808
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.overlay", name: "Overlay")
    }
    private var element: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// A loop observing `pid` with window 11 tracked, its AX list
    /// answering the same window so the branch's reconcile keeps it.
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
        let dummy = element
        loop.axWindows = { _ in box.listed.map { _ in dummy } }
        // One tracked window, so every ask — the reconcile's and
        // the focus arm's own (#1088) — answers it.
        loop.resolveWindowID = { _ in box.listed.first }
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
        loop.elements[pid] = [WindowID(11): dummy]
        box.listed = [WindowID(11)]
        return (loop, box)
    }

    @Test("A report from an app that is not the active app is dropped")
    func inactiveAppReportIsDropped() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = other
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
        #expect(box.focused.isEmpty, "reported \(box.focused)")
        #expect(
            box.logs.contains { $0.contains("app-internal") },
            "no line names the drop: \(box.logs)"
        )
    }

    @Test("A report from the active app is reported")
    func activeAppReportIsReported() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = pid
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
        #expect(box.focused == [WindowID(11)])
    }

    /// Before the first activation notification the frontmost
    /// reading decides, both ways.
    @Test("Before any activation the frontmost app decides")
    func frontmostDecidesBeforeActivation() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = nil
        loop.frontmostPID = { self.other }
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
        #expect(box.focused.isEmpty, "reported \(box.focused)")
        loop.frontmostPID = { self.pid }
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
        #expect(box.focused == [WindowID(11)])
    }

    /// Stated because it fails OPEN: with no activation and no
    /// frontmost reading at all, the report stands rather than
    /// starving focus until the first app switch.
    @Test("With no reading at all the report stands")
    func noReadingLetsTheReportStand() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = nil
        loop.frontmostPID = { nil }
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
        #expect(box.focused == [WindowID(11)])
    }

    /// `stop()` forgets the last activation: the observers are
    /// down for the stopped span, so an activation then is missed,
    /// and a restarted loop that kept the stale pid would drop the
    /// real active app's reports until the next app switch.
    @Test("A restarted loop falls back to the frontmost reading")
    func stopForgetsTheLastActivation() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = other
        loop.frontmostPID = { self.pid }
        loop.stop()
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        loop.elements[pid] = [WindowID(11): element]
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
        #expect(box.focused == [WindowID(11)], "reported \(box.focused)")
    }

    /// The activation memory OUTRANKS the live reading: the
    /// reading is the fallback, never the arbiter, or a frontmost
    /// value that lags the notification would drop the app that
    /// just activated (guard-prover shape).
    @Test("The activation memory outranks the frontmost reading")
    func memoryOutranksTheReading() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = pid
        loop.frontmostPID = { self.other }
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
        #expect(box.focused == [WindowID(11)], "reported \(box.focused)")
    }

    /// An element that answers no id is not reported. Stated
    /// because it is NOT the #1088 route pin: the reconcile that
    /// precedes the ask drops the window from the map too, so the
    /// map route answers nil here as well (guard-prover); the ask
    /// itself is held by the arm's docstring and the rule.
    @Test("An element that no longer answers is not reported")
    func deadElementIsNotReported() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = pid
        loop.resolveWindowID = { _ in nil }
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
        #expect(box.focused.isEmpty, "reported \(box.focused)")
    }

    /// The gate sits AFTER the untracked classification, so an
    /// ignored panel of an inactive app still arms #244's distrust
    /// the way it did before.
    @Test("An untracked window of an inactive app still classifies")
    func untrackedStillClassifies() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = other
        loop.elements[pid] = [:]
        box.listed = []
        loop.resolveWindowID = { _ in WindowID(77) }
        loop.handleFocusedWindowChanged(element, pid: pid, app: ref)
        #expect(box.focused.isEmpty)
        #expect(
            box.logs.contains { $0.contains("untracked w77") },
            "the untracked path did not run: \(box.logs)"
        )
        #expect(!box.logs.contains { $0.contains("app-internal") })
    }
}
