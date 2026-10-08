import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #2002 suites' desk: Space 1 (active) holds the closing
/// window and another app's fallback; the successor, the closing
/// window's app, sits on Space 2 — or on Space 1 when `sameSpace`
/// — and Space 3 holds a third app's window.
@MainActor
struct DelayedCloseFixture {
    let app: pid_t = 50
    let other: pid_t = 60
    let closing = WindowID(1)
    let successor = WindowID(2)
    let fallback = WindowID(3)
    let third = WindowID(4)

    final class Log {
        var lines: [String] = []
        func has(_ needle: String) -> Bool {
            lines.contains { $0.contains(needle) }
        }
    }

    func makeCore(
        sameSpace: Bool = false,
        fallback hasFallback: Bool = true
    ) -> (KiwiCore, Log) {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-2002-\(UUID().uuidString)")
        )
        let now = Date()
        core.wallClock = { now }
        core.desktopMemory.readWindowSpace = { _ in .gone }
        // The follow-up reconcile is the distrust's own business.
        core.eventLoop.onRemovalDistrust = {}
        for space in ["1", "2", "3"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        var members: [(WindowID, pid_t, String)] = [
            (closing, app, "1"),
            (successor, app, sameSpace ? "1" : "2"),
            (third, 70, "3"),
        ]
        if hasFallback { members.append((fallback, other, "1")) }
        for (id, pid, space) in members {
            core.state.windows.upsert(
                ManagedWindow(id: id, pid: pid, appName: "App\(pid)")
            )
            core.state.workspaces.add(id, to: SpaceID(space))
        }
        if !sameSpace {
            core.state.workspaces.focus(successor, in: "2")
        }
        core.state.workspaces.focus(third, in: "3")
        core.state.workspaces.focus(closing, in: "1")
        let log = Log()
        core.onLog = { log.lines.append($0) }
        return (core, log)
    }

    /// Resets the topology override should a confirmation throw.
    func tearDown() {
        NativeSpaces.spacesOverride = nil
    }

    /// The sweep's census refusal: the episode the distrust opens.
    func refuse(_ core: KiwiCore) {
        core.eventLoop.refuseRemoval(
            closing,
            pid: app,
            app: AppRef(bundleID: "com.example.app", name: "App")
        )
    }

    /// macOS keys the successor; the deferred follow is landed by
    /// hand (`deferredFollowReturns` lands it through the queue).
    func keySuccessor(_ core: KiwiCore, follow: Bool = true) {
        core.handle(.windowFocused(successor))
        core.deferred.cancel(.focusFollow)
        if follow {
            core.landFocusFollow(successor, on: "2")
            #expect(core.state.workspaces.activeSpace == "2")
        }
    }

    /// The confirmation, classified `closed` on a pinned topology.
    /// The process-global override lives only inside this one
    /// synchronous main-actor span — the house pattern that keeps
    /// it safe beside other suites, `.serialized` ordering this
    /// suite alone.
    func confirmClose(_ core: KiwiCore, minimized: Bool = false) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        defer { NativeSpaces.spacesOverride = nil }
        core.handle(.windowDestroyed(closing, wasMinimized: minimized))
    }

    /// A window of a third app on the successor's Space.
    func addBystander(_ core: KiwiCore) -> WindowID {
        let id = WindowID(5)
        core.state.windows.upsert(
            ManagedWindow(id: id, pid: 80, appName: "App80")
        )
        core.state.workspaces.add(id, to: "2")
        return id
    }

    func expectReturned(_ core: KiwiCore, _ log: Log) {
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.activeSpace?.focused == fallback)
        #expect(log.has("close-return: raising w\(fallback.raw)"))
    }

    func expectUntouched(_ core: KiwiCore, _ log: Log) {
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.activeSpace?.focused == successor)
        #expect(!log.has("close-return: raising"))
        #expect(core.delayedCloseDebt == nil)
    }
}
