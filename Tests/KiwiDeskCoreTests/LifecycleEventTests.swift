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
        #expect(payload["space"] != nil)
        #expect(payload["space"] != .null)
    }

    @Test("closing fires window_destroyed, not minimized")
    func destroyed() {
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        var events: [KiwiNotification] = []
        core.bus.addSink { event, _ in
            events.append(event)
        }
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: false)
        )
        #expect(events.contains(.windowDestroyed))
        #expect(!events.contains(.windowMinimized))
    }

    @Test("minimizing fires window_minimized, not destroyed")
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
        let names = events.map(\.0)
        #expect(names.contains(.windowMinimized))
        #expect(!names.contains(.windowDestroyed))
        guard
            let (_, data) = events.first(where: {
                $0.0 == .windowMinimized
            }),
            case .object(let payload) = data
        else {
            Issue.record("expected minimized payload")
            return
        }
        #expect(payload["window_id"] == .number(9))
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
