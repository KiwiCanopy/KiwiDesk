import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The fullscreen arm's first beat (#2935): AppKit's transition
/// holds a window on NO Space for ~0.5 s before the fullscreen
/// Space hosts it, and a close still reads hosted when its removal
/// is judged (device, 2026-11-06). Harness: `FullscreenRemovalTests`'
/// per-file copy.
@MainActor
@Suite("Fullscreen transition: hosted nowhere (#2935)")
struct FullscreenBeatRemovalTests {
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

    @Test("the enter beat's first read, hosted nowhere, is refused")
    func enterBeatHostedNowhereIsRefused() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        // #2935: AppKit's transition holds the window on no Space
        // for ~0.5 s before the fullscreen Space hosts it.
        loop.detectedFullscreen[WindowID(12)] = false
        loop.compositorHostsNowhere = { $0 == WindowID(12) }
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = .distantPast
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[WindowID(12)] != nil)
        expectEqual(loop.removalDistrusted[WindowID(12)]?.arms, 1)
        expectEqual(fullscreenLines(box), 1)
    }

    @Test("a close a census refusal watched ends at the recheck")
    func censusEpisodeEndsAtTheBeat() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.detectedFullscreen[WindowID(12)] = false
        var now = Date(timeIntervalSince1970: 1_000)
        loop.wallClock = { now }
        var hostedNowhere = false
        loop.compositorHostsNowhere = { _ in hostedNowhere }
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        loop.lastDesktopChange = .distantPast
        // Finder: unlisted while its close still draws.
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        #expect(loop.removalDistrusted[WindowID(12)]?.cause == nil)
        _ = loop.drainPendingRemovalRecheck()
        hostedNowhere = true
        box.census = [:]
        // An entry's second sweep, inside the beat, holds it.
        now += EventLoop.hostedNowhereBeat - 0.1
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        // The recheck, past it: the close lands.
        now += 0.2
        loop.reconcile(pid: pid, app: ref)
        expectEqual(box.destroyed.map(\.id), [WindowID(12)])
    }

    @Test("a census episode with no sweep in the beat ends past it")
    func censusEpisodeEndsWithOneArmSpent() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.detectedFullscreen[WindowID(12)] = false
        var now = Date(timeIntervalSince1970: 1_000)
        loop.wallClock = { now }
        loop.compositorHostsNowhere = { _ in false }
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        loop.lastDesktopChange = .distantPast
        loop.reconcile(pid: pid, app: ref)
        expectEqual(loop.removalDistrusted[WindowID(12)]?.arms, 1)
        _ = loop.drainPendingRemovalRecheck()
        loop.compositorHostsNowhere = { _ in true }
        box.census = [:]
        // With arms left, only the beat can end it.
        now += EventLoop.hostedNowhereBeat
        loop.reconcile(pid: pid, app: ref)
        expectEqual(box.destroyed.map(\.id), [WindowID(12)])
    }

    @Test("an entry's longest measured beat is still believed")
    func beatCoversAMeasuredEntry() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.detectedFullscreen[WindowID(12)] = false
        var now = Date(timeIntervalSince1970: 1_000)
        loop.wallClock = { now }
        loop.compositorHostsNowhere = { _ in true }
        box.listed = []
        box.census = [:]
        loop.reconcile(pid: pid, app: ref)
        // 512 ms, the longest of six entries (device, 2026-11-06).
        now += 0.512
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
    }

    @Test("nowhere past the beat is a close, one recheck late")
    func hostedNowhereEndsAtTheBeat() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.detectedFullscreen[WindowID(12)] = false
        var now = Date(timeIntervalSince1970: 1_000)
        loop.wallClock = { now }
        loop.compositorHostsNowhere = { _ in true }
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = .distantPast
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        _ = loop.drainPendingRemovalRecheck()
        now += EventLoop.hostedNowhereBeat
        loop.reconcile(pid: pid, app: ref)
        expectEqual(box.destroyed.map(\.id), [WindowID(12)])
    }

    @Test("the fullscreen Space's host outlives the beat")
    func fullscreenHostOutlivesTheBeat() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.detectedFullscreen[WindowID(12)] = false
        var now = Date(timeIntervalSince1970: 1_000)
        loop.wallClock = { now }
        var onFullscreen = false
        loop.compositorHostsNowhere = { _ in !onFullscreen }
        loop.fullscreenSpaceHosts = { _ in onFullscreen }
        box.listed = []
        box.census = [:]
        loop.reconcile(pid: pid, app: ref)
        _ = loop.drainPendingRemovalRecheck()
        onFullscreen = true
        now += EventLoop.hostedNowhereBeat
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
    }

    @Test("the nowhere read never asks the switch grace")
    func hostedNowhereIgnoresTheSwitchGrace() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.detectedFullscreen[WindowID(12)] = false
        loop.compositorHostsNowhere = { _ in true }
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = Date()
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        expectEqual(loop.removalDistrusted[WindowID(12)]?.arms, 1)
    }

    /// The close the beat holds ends at the first recheck only
    /// while the beat is the shorter (`hostedNowhereBeat`'s doc).
    @Test("the beat ends ahead of the first recheck")
    func beatIsShorterThanTheRecheck() {
        let delay = CoreTimings().transientRetrackDelay.components
        let seconds =
            Double(delay.seconds) + Double(delay.attoseconds) / 1e18
        #expect(EventLoop.hostedNowhereBeat < seconds)
    }

    @Test("a beat's sweep between rechecks keeps the window")
    func hostedNowhereSurvivesASecondSweep() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        loop.detectedFullscreen[WindowID(12)] = false
        loop.compositorHostsNowhere = { _ in true }
        let frozen = Date(timeIntervalSince1970: 1_000)
        loop.wallClock = { frozen }
        box.listed = []
        box.census = [:]
        loop.reconcile(pid: pid, app: ref)
        // Another event's reconcile inside the beat, before the
        // recheck: the episode the arm opened keeps it open.
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        expectEqual(loop.removalDistrusted[WindowID(12)]?.arms, 1)
    }

    @Test("a hide and a minimize outrank the nowhere read")
    func hideAndMinimizeOutrankHostedNowhere() {
        let (loop, box) = makeLoop()
        loop.compositorHostsNowhere = { _ in true }
        loop.elements[pid] = [
            WindowID(12): dummyElement,
            WindowID(13): dummyElement,
        ]
        loop.reconcileTabsAndSweep(
            pid: pid,
            app: ref,
            appeared: [],
            live: [WindowID(12)],
            minimized: [WindowID(13)],
            coalesceTabs: false
        )
        expectEqual(box.destroyed.map(\.wasMinimized), [true])
        box.hidden = true
        loop.reconcile(pid: pid, app: ref)
        expectEqual(box.hiddenEvents, [WindowID(12)])
    }
}
