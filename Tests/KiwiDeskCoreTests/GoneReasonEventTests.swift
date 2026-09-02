import Foundation
import Testing

@testable import KiwiDeskCore

/// The gone reason through the real handler (#1146): decided on
/// the compositor's word, read through `DesktopMemory
/// .readWindowSpace` — `makeTestCore` pins it to "no compositor",
/// so each test states its verdict — with the settle stamp
/// deciding only where no topology can be read. Split from
/// `LifecycleEventTests` at the file ceiling.
@MainActor
@Suite("Gone reason through the handler (#1146)", .serialized)
struct GoneReasonEventTests {
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-gone-reason-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: directory)
    }

    private func window(_ id: UInt32) -> ManagedWindow {
        ManagedWindow(id: WindowID(id), pid: 99, appName: "TestApp")
    }

    /// The reason of the first matching event, or nil.
    private func reason(
        of event: KiwiNotification,
        in events: [(KiwiNotification, JSONValue)]
    ) -> JSONValue? {
        guard
            let (_, data) = events.first(where: { $0.0 == event }),
            case .object(let payload) = data
        else { return nil }
        return payload["reason"]
    }

    /// The compositor decides since #1146: the window's Space
    /// and whether some display shows it are pinned, so the
    /// host's WindowServer is never asked about a fake id.
    @Test("a destroy of a window hosted on an unshown Desktop is vanished")
    func vanished() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true),
            authoritySpace(4, display: "UUID-A"),
        ]
        let core = makeCore()
        core.desktopMemory.readWindowSpace = { _ in .hosted(4) }
        core.eventLoop.onEvent(.windowCreated(window(4)))
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
        // The payload names the Desktop it went to (#1146).
        var desktop: JSONValue?
        if case .object(let payload)? = events.first(where: {
            $0.0 == .windowDestroyed
        })?.1 {
            desktop = payload["desktop"]
        }
        #expect(desktop == .number(2))
    }

    @Test("a destroy of a window hosted nowhere is closed, switch or not")
    func closedDespiteTheStamp() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true)
        ]
        let core = makeCore()
        core.desktopMemory.readWindowSpace = { _ in .gone }
        core.eventLoop.onEvent(.windowCreated(window(4)))
        core.lastDesktopSwitch = Date()
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(4), wasMinimized: false)
        )
        #expect(
            reason(of: .windowDestroyed, in: events)
                == .string("closed")
        )
    }

    @Test("without a topology the settle stamp still decides")
    func stampWithoutACompositor() {
        defer { resetAuthorityOverrides() }
        NativeSpaces.spacesOverride = []
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(4)))
        core.lastDesktopSwitch = Date()
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
}
