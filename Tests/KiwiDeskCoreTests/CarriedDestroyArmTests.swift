import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The destroy NOTIFICATION's half of the carried-window arm
/// (#1145): a carried window's element dies as it leaves the
/// visible Space, and inside a switch that destroy defers to the
/// sweep — exactly as a tab carrier's does — while outside one it
/// is the eager close it always was. Split from
/// `CarriedRemovalTests` at the tests.md file ceiling; the harness
/// is that file's per-file copy, on our OWN pid, because `handle`
/// reads the activation policy off the live process table and
/// only our own pid passes that gate (`NotificationWindowIDTests`'
/// shape).
@MainActor
@Suite("Carried-window destroy notification (#1145)")
struct CarriedDestroyArmTests {
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
    }

    private let pid: pid_t = 909_920
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.carried", name: "Carried")
    }

    /// Wires every seam; `attach` is the caller's, so the own-pid
    /// arm can register its observer directly instead.
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
            default:
                break
            }
        }
    }

    /// An inert AX value for seeding `elements` directly.
    private var dummyElement: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// The own-pid loop the notification arm needs: `handle`
    /// reads the policy off the live process table, which only
    /// our own pid answers for.
    private func makeOwnLoop() -> (loop: EventLoop, box: Box, pid: pid_t) {
        let loop = EventLoop()
        let box = Box()
        wire(loop, box)
        let own = pid_t(getpid())
        loop.observers[own] = FakeObserver()
        return (loop, box, own)
    }

    @Test("outside a switch a carried destroy is eager")
    func destroyedNotificationOutsideTheGraceIsEager() {
        let (loop, box, own) = makeOwnLoop()
        let element = dummyElement
        loop.carriedWindows = { [WindowID(12)] }
        loop.elements[own] = [WindowID(12): element]
        box.listed = []
        loop.lastDesktopChange = .distantPast
        loop.handle(
            kAXUIElementDestroyedNotification,
            element,
            pid: own,
            app: AppRef(bundleID: nil, name: "Own")
        )
        #expect(box.destroyed.map(\.id) == [WindowID(12)])
        #expect(loop.elements[own]?[WindowID(12)] == nil)
    }

    @Test("a carried window's destroyed element defers to the sweep")
    func destroyedNotificationDefersToTheSweep() {
        let (loop, box, own) = makeOwnLoop()
        let element = dummyElement
        loop.carriedWindows = { [WindowID(12)] }
        loop.elements[own] = [WindowID(12): element]
        box.listed = []
        box.census = [:]
        loop.lastDesktopChange = Date()
        loop.handle(
            kAXUIElementDestroyedNotification,
            element,
            pid: own,
            app: AppRef(bundleID: nil, name: "Own")
        )
        // No eager destroy: the sweep the arm ran instead refused
        // the carried vanish and kept the registration.
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[own]?[WindowID(12)] != nil)
        #expect(loop.removalDistrusted[WindowID(12)] == 1)
    }

}
