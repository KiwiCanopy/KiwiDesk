import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-lifecycle-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

@MainActor
private func window(
    _ id: UInt32,
    app: String = "TestApp"
) -> ManagedWindow {
    ManagedWindow(id: WindowID(id), pid: 99, appName: app)
}

@Suite("Window lifecycle events", .serialized)
@MainActor
struct LifecycleEventTests {
    @Test("window_created fires with id, app, and space")
    func created() {
        let core = makeCore()
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        core.eventLoop.onEvent(.windowCreated(window(42)))
        guard
            let (_, data) = events.first(where: {
                $0.0 == .windowCreated
            })
        else {
            Issue.record("expected window_created")
            return
        }
        guard case .object(let payload) = data else {
            Issue.record("expected object payload")
            return
        }
        #expect(payload["window_id"] == .number(42))
        #expect(payload["app"] == .string("TestApp"))
        // The window was placed in the active space.
        #expect(payload["space_id"] != nil)
        #expect(payload["space_id"] != .null)
    }

    /// The reason of the first matching event, or nil.
    private func reason(
        of event: KiwiNotification,
        in events: [(KiwiNotification, JSONValue)]
    ) -> JSONValue? {
        guard
            let (_, data) = events.first(where: {
                $0.0 == event
            }),
            case .object(let payload) = data
        else { return nil }
        return payload["reason"]
    }

    @Test("closing fires window_destroyed reason closed")
    func destroyed() {
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: false)
        )
        #expect(
            reason(of: .windowDestroyed, in: events)
                == .string("closed")
        )
    }

    @Test("minimizing fires window_destroyed reason minimized")
    func minimized() {
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(9)))
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(9), wasMinimized: true)
        )
        #expect(
            reason(of: .windowDestroyed, in: events)
                == .string("minimized")
        )
    }

    @Test("a destroy right after a native switch is vanished")
    func vanished() {
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(4)))
        core.lastNativeSwitch = Date()
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(4), wasMinimized: false)
        )
        #expect(
            reason(of: .windowDestroyed, in: events)
                == .string("vanished")
        )
    }

    @Test("deminiaturize fires window_created reason restored")
    func restored() {
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(5)))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(5), wasMinimized: true)
        )
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        core.eventLoop.onEvent(.windowCreated(window(5)))
        #expect(
            reason(of: .windowCreated, in: events)
                == .string("restored")
        )
    }

    @Test("a remembered window returns, a fresh one is new")
    func returnedAndNew() {
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(6)))
        // Native-switch vanish: the space stays remembered.
        core.lastNativeSwitch = Date()
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(6), wasMinimized: false)
        )
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        core.eventLoop.onEvent(.windowCreated(window(6)))
        #expect(
            reason(of: .windowCreated, in: events)
                == .string("returned")
        )
        events.removeAll()
        core.eventLoop.onEvent(.windowCreated(window(60)))
        #expect(
            reason(of: .windowCreated, in: events)
                == .string("new")
        )
    }

    @Test("gone-events report the window's former space")
    func formerSpace() {
        let core = makeCore()
        // Window lands in the active space "1"...
        core.eventLoop.onEvent(
            .windowCreated(window(21, app: "Zen"))
        )
        // ...then the user switches away.
        _ = core.execute(
            "focus_space",
            args: [.string("2")]
        )
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        core.eventLoop.onEvent(
            .windowDestroyed(
                WindowID(21),
                wasMinimized: false
            )
        )
        guard
            let (_, data) = events.first(where: {
                $0.0 == .windowDestroyed
            }),
            case .object(let payload) = data
        else {
            Issue.record("expected destroyed payload")
            return
        }
        // The space it disappeared FROM, not the active one.
        #expect(payload["space_id"] == .string("1"))
        #expect(payload["app"] == .string("Zen"))
    }

    @Test("moving a window across spaces reports from and to")
    func movedToSpace() {
        let core = makeCore()
        core.eventLoop.onEvent(
            .windowCreated(window(31, app: "Spotify"))
        )
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        let response = core.execute(
            "move_to_space",
            args: [.string("3")]
        )
        #expect(response.isSuccess)
        guard
            let (_, data) = events.first(where: {
                $0.0 == .windowMovedToSpace
            }),
            case .object(let payload) = data
        else {
            Issue.record("expected moved-to-space payload")
            return
        }
        #expect(payload["window_id"] == .number(31))
        #expect(payload["app"] == .string("Spotify"))
        #expect(payload["from_space_id"] == .string("1"))
        #expect(payload["to_space_id"] == .string("3"))
        // Moving to the space it is already on stays silent.
        events.removeAll()
        _ = core.execute(
            "move_to_space",
            args: [.string("3")]
        )
        #expect(
            !events.contains { $0.0 == .windowMovedToSpace }
        )
    }

    @Test("lifecycle events reach Lua callbacks")
    func luaCallback() {
        let core = makeCore()
        core.loadConfig()
        guard let lua = core.lua else {
            Issue.record("no VM")
            return
        }
        lua.run(
            """
            KiwiDesk.on("window_created",
                function(id, app, space)
                    created_id = id
                    created_app = app
                end)
            """
        )
        core.eventLoop.onEvent(
            .windowCreated(window(11, app: "Ghostty"))
        )
        #expect(lua.global("created_id") == .number(11))
        #expect(
            lua.global("created_app") == .string("Ghostty")
        )
    }
}
