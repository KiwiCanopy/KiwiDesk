import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `window_created`'s `reason` from the one arrival door (#2630):
/// `existing` for a boot step and for an arrival no WindowServer
/// create followed within `lateCreateBound`, `new` for a create,
/// a dead route and KiwiDesk's own windows, `returned` for a
/// pocketed window re-adopted. Only the emission waits, and a held
/// event goes out before its window's destroy or re-key.
@Suite(
    "window_created reports where a window came from (#2630)",
    .serialized
)
@MainActor
struct LifecycleArrivalReasonTests {
    private typealias Events = [(KiwiNotification, JSONValue)]

    /// A core with the create route `live`, its events and log
    /// lines captured.
    private func makeCore(
        live: Bool = true
    ) -> (KiwiCore, () -> Events, () -> [String]) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-arrival-reason-\(UUID().uuidString)"
                )
        )
        core.windowCreates.isLive = live
        var events: Events = []
        var lines: [String] = []
        core.bus.addSink { events.append(($0, $1)) }
        core.onLog = { lines.append($0) }
        return (core, { events }, { lines })
    }

    private func window(
        _ id: UInt32,
        pid: pid_t = 900_007
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "App",
            appBundleID: "app.test",
            frame: CGRect(x: 100, y: 100, width: 600, height: 400)
        )
    }

    /// Every `window_created` reason sent, in order.
    private func reasons(_ events: Events) -> [JSONValue?] {
        events.filter { $0.0 == .windowCreated }.map {
            guard case .object(let payload) = $0.1 else { return nil }
            return payload["reason"]
        }
    }

    @Test("a boot step's adoption is existing, on every host")
    func bootStepIsExisting() {
        let (core, events, _) = makeCore(live: false)
        core.eventLoop.bootScan.stepBudget = .seconds(1)
        core.eventLoop.onEvent(.windowCreated(window(4)))
        #expect(reasons(events()) == [.string("existing")])
    }

    @Test("a deferred boot app's completion is existing")
    func bootDrainIsExisting() {
        let (core, events, _) = makeCore(live: false)
        core.eventLoop.bootScan.pendingDrain = [
            (900_007, AppRef(pid: 900_007))
        ]
        core.eventLoop.onEvent(.windowCreated(window(4)))
        core.eventLoop.onEvent(
            .windowCreated(window(5, pid: 900_008))
        )
        #expect(
            reasons(events()) == [.string("existing"), .string("new")]
        )
    }

    @Test("without the create route an arrival is new at once")
    func deadRouteIsNew() {
        let (core, events, _) = makeCore(live: false)
        core.eventLoop.onEvent(.windowCreated(window(4)))
        #expect(reasons(events()) == [.string("new")])
    }

    @Test("a create seen before the arrival is new at once")
    func createdFirstIsNew() {
        let (core, events, _) = makeCore()
        core.windowServerChanged(.created, id: WindowID(4))
        core.eventLoop.onEvent(.windowCreated(window(4)))
        #expect(reasons(events()) == [.string("new")])
    }

    @Test("a create after the adoption is held, then new")
    func lateCreateIsHeldThenNew() {
        let (core, events, _) = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(4)))
        // Placed and focused now; only the event waits.
        #expect(reasons(events()).isEmpty)
        #expect(core.state.workspaces.space(of: WindowID(4)) != nil)
        #expect(core.deferred.task(for: .arrivalBound) != nil)
        core.windowServerChanged(.created, id: WindowID(4))
        #expect(reasons(events()) == [.string("new")])
        #expect(core.arrivals.waiting.isEmpty)
    }

    @Test("no create within the bound is existing, logged once")
    func boundPassedIsExisting() {
        let (core, events, lines) = makeCore()
        core.eventLoop.arrivingFromAXCreate = true
        core.eventLoop.onEvent(.windowCreated(window(4)))
        core.eventLoop.arrivingFromAXCreate = false
        let arrived = core.wallClock()
        core.wallClock = {
            arrived.addingTimeInterval(
                LaunchFollowIntent.lateCreateBound
            )
        }
        core.resolveExpiredArrivals()
        #expect(reasons(events()) == [.string("existing")])
        let timeouts = lines().filter {
            $0.contains("no WindowServer create within")
        }
        #expect(timeouts.count == 1)
        #expect(timeouts.first?.contains("app.test") == true)
        #expect(timeouts.first?.contains("AX create: yes") == true)
        // A create past the bound changes nothing.
        core.windowServerChanged(.created, id: WindowID(4))
        #expect(reasons(events()) == [.string("existing")])
    }

    @Test("a create past the bound, before the timer, is existing")
    func lateCreatePastTheBound() {
        let (core, events, lines) = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(4)))
        let arrived = core.wallClock()
        core.wallClock = {
            arrived.addingTimeInterval(
                LaunchFollowIntent.lateCreateBound + 0.1
            )
        }
        core.windowServerChanged(.created, id: WindowID(4))
        #expect(reasons(events()) == [.string("existing")])
        #expect(lines().contains { $0.contains("AX create: no") })
    }

    @Test("KiwiDesk's own window is new, never held")
    func ownWindowIsNew() {
        let (core, events, _) = makeCore()
        core.eventLoop.onEvent(
            .windowCreated(window(4, pid: getpid()))
        )
        #expect(reasons(events()) == [.string("new")])
        #expect(core.arrivals.waiting.isEmpty)
    }

    @Test("a pocketed window re-adopted after a hide is returned")
    func pocketReturnIsReturned() {
        let (core, events, _) = makeCore()
        core.windowServerChanged(.created, id: WindowID(4))
        core.eventLoop.onEvent(.windowCreated(window(4)))
        core.state.apply(.windowFocused(WindowID(4)))
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: WindowID(4)) == .pocketed)
        core.eventLoop.onEvent(.windowHidden(WindowID(4)))
        core.eventLoop.onEvent(.windowCreated(window(4)))
        #expect(
            reasons(events()) == [.string("new"), .string("returned")]
        )
    }

    @Test("a held window's destroy sends its create first")
    func destroyFlushesTheHeldCreate() {
        let (core, events, _) = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(4)))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(4), wasMinimized: false)
        )
        let kinds = events().map(\.0).filter {
            $0 == .windowCreated || $0 == .windowDestroyed
        }
        #expect(kinds == [.windowCreated, .windowDestroyed])
        #expect(reasons(events()) == [.string("existing")])
        guard case .object(let created)? = events().first?.1 else {
            Issue.record("expected window_created first")
            return
        }
        // The Space it held, though state has let it go.
        #expect(created["space_id"] != .null)
        #expect(core.arrivals.waiting.isEmpty)
    }

    @Test("a held window's re-key sends its create first")
    func rekeyFlushesTheHeldCreate() {
        let (core, events, _) = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(4)))
        core.eventLoop.onEvent(
            .windowRekeyed(WindowID(4), WindowID(5))
        )
        #expect(reasons(events()) == [.string("existing")])
        #expect(core.arrivals.waiting.isEmpty)
    }

    @Test("a stop drops a held create")
    func stopDropsTheHold() {
        let (core, _, _) = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(4)))
        #expect(!core.arrivals.waiting.isEmpty)
        core.stop()
        #expect(core.arrivals.waiting.isEmpty)
    }
}
