import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// What the loop does with a shadow once it knows one (#1785):
/// hands back one it tracked, drops the focus report naming it,
/// names a real window for a polled focus read, and keeps it out
/// of the tab re-key. Split from `ShadowWindowTests` at the file
/// ceiling; its own per-file harness (tests.md).
@MainActor
@Suite("Shadow windows in the reconcile (#1785)")
struct ShadowWindowReconcileTests {
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

    // MARK: - Handing a tracked shadow back

    @Test("a tracked shell beside its host leaves as a hide")
    func trackedShellIsHandedBack() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, box) = makeLoop([host, twin])
        loop.elements[pid] = [host.id: element(0), twin.id: element(1)]
        loop.retireShadows(pid: pid, listed: listed(box, [0, 1]))
        #expect(box.hidden == [twin.id])
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[twin.id] == nil)
        #expect(loop.elements[pid]?[host.id] != nil)
        #expect(loop.shadows.holds(twin.id, pid: pid))
        #expect(box.logs.contains { $0.contains("handed back") })
    }

    @Test("a tracked shell alone, content or an unread window stays")
    func onlyAnExplainedShellLeaves() {
        let lone = traits(1, buttons: false, children: 0)
        let content = traits(2, buttons: false, children: 5)
        let unread = traits(3, buttons: nil, children: nil)
        let (loop, box) = makeLoop([lone, content, unread])
        loop.elements[pid] = [
            lone.id: element(0), content.id: element(1),
            unread.id: element(2),
        ]
        loop.retireShadows(pid: pid, listed: listed(box, [0, 1, 2]))
        #expect(box.hidden.isEmpty)
        #expect(loop.elements[pid]?.count == 3)
    }

    @Test("only a tracked window the pass listed is read, once")
    func readsOnlyWhatThePassListed() {
        let host = traits(1, buttons: true, children: 6)
        let away = traits(2, buttons: true, children: 6)
        let untracked = traits(3, buttons: false, children: 0)
        let (loop, box) = makeLoop([host, away, untracked])
        loop.elements[pid] = [host.id: element(0), away.id: element(1)]
        loop.retireShadows(pid: pid, listed: listed(box, [0, 2]))
        #expect(box.traitReads == [host.id])
        #expect(box.hidden.isEmpty)
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
