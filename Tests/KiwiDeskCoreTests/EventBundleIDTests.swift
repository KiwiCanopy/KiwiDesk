import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-bundleid-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

@MainActor
private func window(
    _ id: UInt32,
    app: String = "TestApp",
    bundleID: String? = "com.test.app"
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 99,
        appName: app,
        appBundleID: bundleID
    )
}

/// The first payload of `event`, or nil.
@MainActor
private func payload(
    of event: KiwiNotification,
    in events: [(KiwiNotification, JSONValue)]
) -> [String: JSONValue]? {
    guard
        let (_, data) = events.first(where: { $0.0 == event }),
        case .object(let payload) = data
    else { return nil }
    return payload
}

/// Window events carry the stable `bundle_id` alongside the
/// display `app` name (#265) — the event stream must not be
/// identity-blind.
@Suite("Window event bundle ids", .serialized)
@MainActor
struct EventBundleIDTests {
    @Test("window_created carries bundle_id")
    func created() {
        let core = makeCore()
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }
        core.eventLoop.onEvent(.windowCreated(window(42)))
        #expect(
            payload(of: .windowCreated, in: events)?[
                "bundle_id"
            ] == .string("com.test.app")
        )
    }

    @Test("an unbundled process reports JSON null")
    func unbundled() {
        let core = makeCore()
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }
        core.eventLoop.onEvent(
            .windowCreated(window(43, bundleID: nil))
        )
        #expect(
            payload(of: .windowCreated, in: events)?[
                "bundle_id"
            ] == .null
        )
    }

    @Test("focus_change carries bundle_id")
    func focus() {
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(.windowCreated(window(8)))
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }
        core.eventLoop.onEvent(.windowFocused(WindowID(7)))
        #expect(
            payload(of: .focusChange, in: events)?[
                "bundle_id"
            ] == .string("com.test.app")
        )
    }

    @Test("window_destroyed reports the erased bundle_id")
    func destroyed() {
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(9)))
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }
        // The removal erases the window from state — the
        // payload must come from the pre-removal snapshot.
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(9), wasMinimized: false)
        )
        #expect(
            payload(of: .windowDestroyed, in: events)?[
                "bundle_id"
            ] == .string("com.test.app")
        )
    }

    @Test("window_moved_to_space carries bundle_id")
    func moved() {
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(31)))
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }
        let response = core.execute(
            "move_to_space",
            args: [.string("3")]
        )
        #expect(response.isSuccess)
        #expect(
            payload(of: .windowMovedToSpace, in: events)?[
                "bundle_id"
            ] == .string("com.test.app")
        )
    }

    @Test("Lua callbacks receive the appended bundle id")
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
                function(id, app, space, reason, bundle)
                    created_bundle = bundle
                end)
            """
        )
        core.eventLoop.onEvent(.windowCreated(window(11)))
        #expect(
            lua.global("created_bundle")
                == .string("com.test.app")
        )
        // Nil bundle arrives as "" so the arg list can't
        // truncate.
        core.eventLoop.onEvent(
            .windowCreated(window(12, bundleID: nil))
        )
        #expect(lua.global("created_bundle") == .string(""))
    }
}
