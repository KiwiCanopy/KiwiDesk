import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// A hidden app releases its tiles (#913).
///
/// The defect this pins: ⌘H — and an Electron app hiding itself
/// as its last window closes, which is what Discord's red X
/// does — leaves every window in `kAXWindows`, un-minimized and
/// at its last frame. Reconcile read that as "still up", so the
/// window kept its slot, its App Bar item and its layout share
/// until the app quit. Minimize never had the bug because it is
/// the one case that flips `AXMinimized`.
///
/// One obligation in `.claude/rules/accessibility.md`'s hidden
/// bullet is deliberately NOT discriminated here: the refusal
/// inside `track`. Its door is an app opening a window while
/// hidden, and with a fabricated AX element `track` returns at
/// its role check whatever the refusal does — so an assertion
/// here would pass with the guard deleted, which is worse than
/// no assertion. It is defence in depth for a door not shown to
/// be reachable; `HiddenAppTrackNeedleTests` pins its presence
/// and position via `SourceScan`.
///
/// Everything drives the funnels through the injected seams
/// (tests.md); no app is hidden, attached to or messaged for
/// real. The AX values are inert dictionary entries — the hidden
/// path never messages them, which is itself one of the claims
/// below.
@MainActor
@Suite("Hidden apps release their windows")
struct HiddenAppWindowTests {
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
        var windowQueries = 0
        var hidden = false
        /// What the app's AX window list reports.
        var listed: [WindowID] = []
        var cursor = 0
        /// Reconcile's first machine read, so it counts a pass
        /// that ENTERED — including one that turns straight
        /// round and detaches, which no window-list count can
        /// see.
        var policyReads = 0
        /// The EUI warm's read — #662's promise is that a
        /// skipped app is warmed anyway, and a hidden app must
        /// not lose it.
        var euiReads = 0
        /// `.windowHidden` ids, kept apart from `destroyed`:
        /// the two differ in the public reason they produce
        /// and in whether the close-return raise runs.
        var hiddenEvents: [WindowID] = []
        var destroyed: [(id: WindowID, wasMinimized: Bool)] = []
    }

    private let pid: pid_t = 909_909
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.hidden", name: "Hidden")
    }

    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.runningApplications = { [] }
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = { _ in
            box.euiReads += 1
            return false
        }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.activationPolicy = { _ in
            box.policyReads += 1
            return .regular
        }
        loop.onScreenNormalWindowIDs = { [:] }
        // The app KEEPS listing its windows while hidden —
        // that is the whole defect — so the fake list must
        // answer with them, and `resolveWindowID` must map them
        // back. An empty list would make the sweep destroy
        // everything for want of a live id, which is what the
        // guard deleted does: three assertions below passed
        // that way in draft.
        loop.axWindows = { _ in
            box.windowQueries += 1
            box.cursor = 0
            return box.listed.map { _ in self.dummyElement }
        }
        // One element per listed id, in order — a fake element
        // carries nothing to tell two apart, so the cursor is
        // what pairs them up.
        loop.resolveWindowID = { _ in
            defer { box.cursor += 1 }
            guard box.cursor < box.listed.count else { return nil }
            return box.listed[box.cursor]
        }
        loop.appIsHidden = { _ in box.hidden }
        loop.onEvent = { event in
            switch event {
            case .windowDestroyed(let id, let wasMinimized):
                box.destroyed.append(
                    (id: id, wasMinimized: wasMinimized)
                )
            case .windowHidden(let id):
                box.hiddenEvents.append(id)
            default:
                break
            }
        }
        // `attach` refuses before `start()` (#672), and a
        // reconcile without an observer detaches instead of
        // reaching the hidden path at all — so every claim here
        // would pass for the wrong reason on an unstarted loop.
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        box.policyReads = 0
        box.euiReads = 0
        return (loop, box)
    }

    private func attach(
        _ loop: EventLoop,
        scanWindowsAtAttach: Bool = false
    ) {
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: scanWindowsAtAttach
        )
    }

    /// An inert AX value for seeding `elements` directly.
    private var dummyElement: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    @Test("hiding an app drops every window it had tracked")
    func hidingDropsTrackedWindows() {
        let (loop, box) = makeLoop()
        attach(loop)
        loop.elements[pid] = [
            WindowID(11): dummyElement,
            WindowID(12): dummyElement,
        ]
        box.listed = [WindowID(11), WindowID(12)]
        box.hidden = true
        loop.reconcile(pid: pid, app: ref)
        #expect(
            box.hiddenEvents.sorted { $0.raw < $1.raw }
                == [WindowID(11), WindowID(12)]
        )
        // Never as destroys: a consumer told `closed` fires
        // whatever it does for a real close.
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid, default: [:]].isEmpty)
    }

    @Test("the drop keeps the window's Desktop, unlike a park")
    func dropIsNotAMinimize() {
        // The fold behind `.windowHidden` is a NON-minimized
        // destroy: that is what decides between remembering the
        // window's space and forgetting it for the Dock, and a
        // hidden window comes back where it was. Asserted on
        // the fold's own output rather than on the event, since
        // the event carries no flag to read.
        let (loop, box) = makeLoop()
        attach(loop)
        loop.elements[pid] = [WindowID(11): dummyElement]
        box.listed = [WindowID(11)]
        box.hidden = true
        loop.reconcile(pid: pid, app: ref)
        #expect(box.hiddenEvents == [WindowID(11)])

        var state = StateCoordinator()
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(11),
                    pid: pid,
                    appName: "Hidden",
                    appBundleID: "test.kiwi.hidden",
                    title: "W11"
                )
            )
        )
        state.apply(.windowHidden(WindowID(11)))
        #expect(state.windows[WindowID(11)] == nil)
        // The space is REMEMBERED (the non-minimized arm); a
        // minimize would have cleared it and filed a park
        // record instead.
        #expect(state.rememberedSpaces[WindowID(11)] != nil)
        #expect(state.lastMinimized(bundleID: "test.kiwi.hidden") == nil)
    }

    @Test("the drop costs no AX window read")
    func dropSkipsTheWindowList() {
        // Hidden is a total answer about the app, so the list
        // has nothing left to say — and reading it is blocking
        // IPC into an app that is, by definition, not on screen.
        let (loop, box) = makeLoop()
        attach(loop)
        loop.elements[pid] = [WindowID(11): dummyElement]
        box.listed = [WindowID(11)]
        box.hidden = true
        loop.reconcile(pid: pid, app: ref)
        #expect(box.windowQueries == 0)
    }

    @Test("a visible app still reads its window list")
    func visibleAppStillReconcilesNormally() {
        // The control: without it, a guard that dropped the AX
        // read unconditionally would pass every claim above.
        let (loop, box) = makeLoop()
        attach(loop)
        loop.elements[pid] = [WindowID(11): dummyElement]
        box.listed = [WindowID(11)]
        loop.reconcile(pid: pid, app: ref)
        #expect(box.windowQueries == 1)
        #expect(box.destroyed.isEmpty)
    }

    @Test("attach does not adopt a hidden app's windows")
    func attachSkipsAHiddenApp() {
        // Boot's way into the same defect: AX lists the windows
        // of an app hidden long before KiwiDesk started, and the
        // startup scan would tile them sight unseen.
        let (loop, box) = makeLoop()
        box.hidden = true
        attach(loop, scanWindowsAtAttach: true)
        #expect(loop.observes(pid: pid))
        #expect(box.windowQueries == 0)
    }

    @Test("a hidden app is warmed even though it is not adopted")
    func hiddenAppIsStillWarmed() {
        // #662's promise — a following reconcile warms whatever
        // attach skipped — does not reach a hidden app, because
        // both hidden paths return before that warm. An app
        // hidden across boot would then meet its first unhide
        // with a cold AX tree, which for an Electron app means
        // an empty window list, putting the window back on the
        // heal's latency instead of the gesture.
        let (loop, box) = makeLoop()
        box.hidden = true
        attach(loop, scanWindowsAtAttach: true)
        #expect(box.euiReads == 1)
        #expect(box.windowQueries == 0)
    }

    @Test("attach still scans a visible app")
    func attachScansAVisibleApp() {
        let (loop, box) = makeLoop()
        attach(loop, scanWindowsAtAttach: true)
        #expect(box.windowQueries == 1)
    }

    @Test("a hide or unhide reconciles the app at once")
    func hideChangeFunnelsToReconcile() {
        // Both directions take one arm, so the release lands on
        // the gesture rather than whenever something else
        // happens to reconcile the app.
        //
        // The hidden half reads a hide EFFECT, not the absence
        // of a window read: `windowQueries == 1` after the hide
        // is satisfied identically by the wired arm, by an arm
        // that returned early, and by a reconcile that skipped
        // the sweep — three states the test claims to tell
        // apart. Only the emitted event does.
        let (loop, box) = makeLoop()
        attach(loop)
        loop.elements[pid] = [WindowID(11): dummyElement]
        box.listed = [WindowID(11)]
        loop.appHideChanged(pid: pid, ref: ref)
        #expect(box.windowQueries == 1)
        #expect(box.hiddenEvents.isEmpty)
        box.hidden = true
        loop.appHideChanged(pid: pid, ref: ref)
        #expect(box.windowQueries == 1)
        #expect(box.hiddenEvents == [WindowID(11)])
    }

    @Test("an unobserved app's hide reconciles nothing")
    func hideChangeIgnoresUnobservedApps() {
        // Counted on the policy read, not the window list: an
        // observerless reconcile detaches and returns before it
        // ever reads a window, so a window-list count passes
        // whether the guard is there or not — which is how this
        // test read in draft.
        let (loop, box) = makeLoop()
        loop.appHideChanged(pid: pid, ref: ref)
        #expect(box.policyReads == 0)
    }
}
