import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// A shadow's focus and its place in the tab re-key (#1785): the
/// report naming it is dropped, a polled read names a real window
/// of its process, and it never takes a vanished carrier's slot.
/// Split from `ShadowWindowReconcileTests` at the file ceiling;
/// its own per-file harness (tests.md).
@MainActor
@Suite("Shadow windows and focus (#1785)")
struct ShadowWindowFocusTests {
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
        var windows: [WindowTraits] = []
        var traitReads: [WindowID] = []
        var hidden: [WindowID] = []
        var destroyed: [WindowID] = []
        var rekeyed: [WindowID] = []
        var focused: [WindowID] = []
        var logs: [String] = []
        var front: [(id: WindowID, pid: pid_t)] = []
        var answer: WindowID?
    }

    private let pid: pid_t = 178_801
    private let frame = CGRect(x: 75, y: 86, width: 821, height: 1025)
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.browser", name: "Browser")
    }

    private func traits(
        _ id: UInt32,
        buttons: Bool?,
        children: Int?
    ) -> WindowTraits {
        WindowTraits(
            id: WindowID(id),
            hasTitlebarButton: buttons,
            childCount: children,
            frame: frame
        )
    }

    private func element(_ index: Int) -> AXUIElement {
        AXUIElementCreateApplication(pid_t(910_000 + index))
    }

    private func makeLoop(
        _ windows: [WindowTraits]
    ) -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        box.windows = windows
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
        loop.processIdentity.frontToBack = { box.front }
        let elements = windows.indices.map(element)
        loop.shadows.traits = { element, _ in
            let index = elements.firstIndex { CFEqual($0, element) }
            let traits = index.map { box.windows[$0] }
            if let traits { box.traitReads.append(traits.id) }
            return traits
        }
        loop.resolveWindowID = { _ in box.answer }
        loop.onEvent = { event in
            switch event {
            case .windowHidden(let id): box.hidden.append(id)
            case .windowDestroyed(let id, _): box.destroyed.append(id)
            case .windowRekeyed(let from, _): box.rekeyed.append(from)
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
        return (loop, box)
    }

    private func listed(
        _ box: Box,
        _ indices: [Int]
    ) -> [(element: AXUIElement, id: WindowID)] {
        indices.map { (element($0), box.windows[$0].id) }
    }

    /// A budget with no deadline — an OS-driven reconcile's — or
    /// one already spent.
    private func budget(spent: Bool) -> EventLoop.AppBudget {
        let now = ContinuousClock.now
        return EventLoop.AppBudget(
            openedAt: now,
            deadline: spent ? now : nil,
            now: { ContinuousClock.now }
        )
    }

    private func retire(
        _ loop: EventLoop,
        _ box: Box,
        _ indices: [Int],
        spent: Bool = false
    ) -> Bool {
        loop.retireShadows(
            pid: pid,
            listed: listed(box, indices),
            budget: budget(spent: spent)
        )
    }

    // MARK: - Focus

    @Test("a focus report naming a shadow is dropped")
    func shadowReportIsDropped() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, box) = makeLoop([host, twin])
        loop.elements[pid] = [host.id: element(0)]
        loop.axWindows = { _ in [self.element(0), self.element(1)] }
        loop.resolveWindowID = { element in
            CFEqual(element, self.element(1)) ? twin.id : host.id
        }
        loop.lastActivePid = pid
        // `track` asks the verdict; an inert element never gets
        // that far, so the suite asks it as `track` would.
        #expect(
            loop.shadowVerdict(element(1), id: twin.id, pid: pid)
                == .shadow
        )
        box.logs = []
        loop.handleFocusedWindowChanged(element(1), pid: pid, app: ref)
        #expect(box.focused.isEmpty)
        #expect(
            box.logs.contains {
                $0 == "focus: w\(twin.id.raw) is a shadow "
                    + "(pid \(pid)) — dropped"
            },
            "logs: \(box.logs)"
        )
        // The host stays tracked: the report moved nothing.
        #expect(loop.elements[pid]?[host.id] != nil)
        #expect(box.hidden.isEmpty && box.destroyed.isEmpty)
    }

    @Test("a polled focus naming a shadow names a real window")
    func polledFocusNamesARealWindow() {
        let first = traits(1, buttons: true, children: 6)
        let second = traits(2, buttons: true, children: 6)
        let twin = traits(3, buttons: false, children: 0)
        let (loop, box) = makeLoop([first, second, twin])
        loop.axWindows = { _ in
            [self.element(0), self.element(1), self.element(2)]
        }
        #expect(
            loop.shadowVerdict(element(2), id: twin.id, pid: pid)
                == .shadow
        )
        loop.shadows.focusedWindow = { _ in twin.id }
        // None tracked: the host it was judged against.
        #expect(loop.focusedWindowID(pid: pid) == first.id)
        // One tracked: that one.
        loop.elements[pid] = [second.id: element(1)]
        #expect(loop.focusedWindowID(pid: pid) == second.id)
        // Several: the front-most TRACKED one of this process —
        // never the shadow in front of it, nor another's window.
        loop.elements[pid] = [first.id: element(0), second.id: element(1)]
        box.front = [
            (twin.id, pid), (WindowID(9), pid + 1), (second.id, pid),
            (first.id, pid),
        ]
        #expect(loop.focusedWindowID(pid: pid) == second.id)
        // A real window names itself.
        loop.shadows.focusedWindow = { _ in first.id }
        #expect(loop.focusedWindowID(pid: pid) == first.id)
    }

    // MARK: - Tabs

    @Test("a shadow never takes a vanished carrier's slot")
    func shadowIsNoTab() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, box) = makeLoop([host, twin])
        loop.axWindows = { _ in [self.element(0), self.element(1)] }
        #expect(
            loop.shadowVerdict(element(1), id: twin.id, pid: pid)
                == .shadow
        )
        // The carrier vanishes on the frame an inert element
        // reads, which is what a re-key matches on.
        loop.elements[pid] = [host.id: element(0)]
        loop.tabCarriers = [host.id]
        loop.trackedFrames[host.id] = AXHelper.frame(of: element(1))
        loop.reconcileTabsAndSweep(
            pid: pid,
            app: ref,
            appeared: [(element: element(1), id: twin.id)],
            live: [twin.id],
            minimized: [],
            coalesceTabs: true
        )
        #expect(box.rekeyed.isEmpty)
        #expect(box.destroyed == [host.id])
        #expect(loop.elements[pid]?[twin.id] == nil)
    }
}
