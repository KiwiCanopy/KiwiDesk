import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The destroy NOTIFICATION's half of the fullscreen arm (#1272):
/// an app that reports the ordered-out window destroyed during
/// its fullscreen transition defers to the sweep — exactly as a
/// tab carrier's and a carried window's do — on the ONE reading
/// the sweep takes (`expectedAbsence`), while a window no arm
/// expects takes the eager close it always did. Split from
/// `FullscreenRemovalTests` at the tests.md file ceiling; the
/// harness is `CarriedDestroyArmTests`' per-file copy, on our OWN
/// pid, because `handle` reads the activation policy off the live
/// process table and only our own pid passes that gate.
@MainActor
@Suite("Fullscreen-transition destroy notification (#1272)")
struct FullscreenDestroyArmTests {
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
        var listed: [WindowID] = []
        var cursor = 0
        var census: [pid_t: Set<WindowID>] = [:]
        var censusReads = 0
        var destroyed: [WindowID] = []
    }

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
        loop.onScreenNormalWindowIDs = {
            box.censusReads += 1
            return box.census
        }
        loop.onRemovalDistrust = {}
        loop.axWindows = { _ in
            box.cursor = 0
            return box.listed.map { _ in self.dummyElement }
        }
        loop.resolveWindowID = { _ in
            defer { box.cursor += 1 }
            guard box.cursor < box.listed.count else { return nil }
            return box.listed[box.cursor]
        }
        loop.appIsHidden = { _ in false }
        loop.onEvent = { event in
            if case .windowDestroyed(let id, _) = event {
                box.destroyed.append(id)
            }
        }
    }

    /// The own-pid loop the notification arm needs.
    private func makeOwnLoop() -> (loop: EventLoop, box: Box, pid: pid_t) {
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        let own = pid_t(getpid())
        loop.observers[own] = FakeObserver()
        return (loop, box, own)
    }

    private var dummyElement: AXUIElement {
        AXUIElementCreateApplication(pid_t(getpid()))
    }

    private var own: AppRef { AppRef(bundleID: nil, name: "Own") }

    @Test("a fullscreen window's destroyed element defers to the sweep")
    func exitDestroyDefersToTheSweep() {
        let (loop, box, pid) = makeOwnLoop()
        let element = dummyElement
        loop.detectedFullscreen[WindowID(12)] = true
        loop.fullscreenSpaceHosts = { _ in false }
        loop.elements[pid] = [WindowID(12): element]
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = .distantPast
        loop.handle(
            kAXUIElementDestroyedNotification,
            element,
            pid: pid,
            app: own
        )
        // No eager destroy: the sweep the arm ran instead refused
        // the vanish and kept the registration.
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[WindowID(12)] != nil)
        #expect(loop.removalDistrusted[WindowID(12)] == 1)
    }

    @Test("a window the compositor hosts on a fullscreen Space defers too")
    func enterDestroyDefersToTheSweep() {
        let (loop, box, pid) = makeOwnLoop()
        let element = dummyElement
        loop.detectedFullscreen[WindowID(12)] = false
        loop.fullscreenSpaceHosts = { $0 == WindowID(12) }
        loop.elements[pid] = [WindowID(12): element]
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = .distantPast
        loop.handle(
            kAXUIElementDestroyedNotification,
            element,
            pid: pid,
            app: own
        )
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[WindowID(12)] != nil)
        #expect(loop.removalDistrusted[WindowID(12)] == 1)
    }

    @Test("a window no arm expects destroys eagerly")
    func plainDestroyIsEager() {
        let (loop, box, pid) = makeOwnLoop()
        let element = dummyElement
        loop.detectedFullscreen[WindowID(12)] = false
        loop.fullscreenSpaceHosts = { _ in false }
        loop.elements[pid] = [WindowID(12): element]
        box.listed = []
        loop.lastDesktopChange = .distantPast
        loop.handle(
            kAXUIElementDestroyedNotification,
            element,
            pid: pid,
            app: own
        )
        #expect(box.destroyed == [WindowID(12)])
        #expect(loop.elements[pid]?[WindowID(12)] == nil)
        // EAGER: the registration went before the reconcile, so
        // the sweep found nothing vanished and read no census.
        #expect(box.censusReads == 0)
    }
}
