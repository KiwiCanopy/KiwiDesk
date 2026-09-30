import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// What a reconcile does with a shadow once it knows one (#1785):
/// hands back one it tracked, reads only what the pass listed,
/// ends a record with its host and keeps to the boot budget. Its
/// focus half is `ShadowWindowFocusTests`'; split at the file
/// ceiling, its own per-file harness (tests.md).
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

    // MARK: - Handing a tracked shadow back

    @Test("a tracked shell beside its host leaves as a hide")
    func trackedShellIsHandedBack() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, box) = makeLoop([host, twin])
        loop.elements[pid] = [host.id: element(0), twin.id: element(1)]
        #expect(retire(loop, box, [0, 1]))
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
        #expect(retire(loop, box, [0, 1, 2]))
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
        #expect(retire(loop, box, [0, 2]))
        #expect(box.traitReads == [host.id])
        #expect(box.hidden.isEmpty)
    }

    /// The wiring: a budget spent between two of the retire
    /// pass's reads defers the app to the pass's epilogue (#803),
    /// which a silent skip ahead of the call — the shape this
    /// replaced — never does. An OS-driven reconcile carries no
    /// deadline and is never deferred.
    @Test("a budget spent mid-pass defers the app, never silently")
    func spentBudgetMidPassDefersTheApp() {
        let host = traits(1, buttons: true, children: 6)
        let other = traits(2, buttons: true, children: 6)
        let (loop, box) = makeLoop([host, other])
        loop.elements[pid] = [host.id: element(0), other.id: element(1)]
        loop.axWindows = { _ in [self.element(0), self.element(1)] }
        loop.resolveWindowID = { element in
            CFEqual(element, self.element(0)) ? host.id : other.id
        }
        loop.onScreenNormalWindowIDs = { [self.pid: [host.id, other.id]] }
        var now = ContinuousClock.now
        loop.monotonicNow = { now }
        // The first read spends the step's budget; the second
        // read's checkpoint sees it.
        let reads = loop.shadows.traits
        loop.shadows.traits = { element, id in
            now = now.advanced(by: .seconds(1))
            return reads(element, id)
        }
        loop.bootScan.stepBudget = .milliseconds(500)
        loop.reconcile(pid: pid, app: ref)
        #expect(box.traitReads.count == 1)
        #expect(loop.takeDeferredBootApps().keys.contains(pid))
        // Outside a queued step the same reads never defer.
        loop.bootScan.stepBudget = nil
        box.traitReads = []
        loop.reconcile(pid: pid, app: ref)
        #expect(box.traitReads.count == 2)
        #expect(loop.takeDeferredBootApps().isEmpty)
    }

    @Test("a spent boot budget reads nothing and says so")
    func spentBudgetReadsNothing() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, box) = makeLoop([host, twin])
        loop.elements[pid] = [host.id: element(0), twin.id: element(1)]
        #expect(!retire(loop, box, [0, 1], spent: true))
        #expect(box.traitReads.isEmpty)
        #expect(box.hidden.isEmpty)
        // One listed window pays nothing, budget or not.
        #expect(retire(loop, box, [0], spent: true))
    }

    @Test("a pass listing one window reads nothing")
    func oneListedWindowIsNotRead() {
        let lone = traits(1, buttons: false, children: 0)
        let (loop, box) = makeLoop([lone])
        loop.elements[pid] = [lone.id: element(0)]
        #expect(retire(loop, box, [0]))
        #expect(box.traitReads.isEmpty)
        #expect(box.hidden.isEmpty)
    }

    @Test("a record dies with its host, at the reconcile that lost it")
    func recordDiesWithItsHost() {
        let host = traits(1, buttons: true, children: 6)
        let twin = traits(2, buttons: false, children: 0)
        let (loop, box) = makeLoop([host, twin])
        var listed = [element(0), element(1)]
        loop.axWindows = { _ in listed }
        loop.resolveWindowID = { element in
            CFEqual(element, self.element(0)) ? host.id : twin.id
        }
        #expect(
            loop.shadowVerdict(element(1), id: twin.id, pid: pid)
                == .shadow
        )
        // The host still listed, the twin not: the record holds.
        listed = [element(0)]
        loop.reconcile(pid: pid, app: ref)
        #expect(loop.shadows.holds(twin.id, pid: pid))
        // The host closed: the twin is a window again until a
        // sibling explains it — a false positive ends here.
        listed = [element(1)]
        loop.reconcile(pid: pid, app: ref)
        #expect(!loop.shadows.holds(twin.id, pid: pid))
    }
}
