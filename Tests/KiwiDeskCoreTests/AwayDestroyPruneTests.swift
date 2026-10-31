import Foundation
import Testing

@testable import KiwiDeskCore

/// An away window WindowServer reports destroyed is pruned on the
/// compositor's per-window word (#2660), so the whole-list census
/// is a slow backstop while that route is live.
@MainActor
@Suite("An away window's destroy prunes it", .serialized)
struct AwayDestroyPruneTests {
    private final class Sleeps: @unchecked Sendable {
        private let lock = NSLock()
        private var waits: [Duration] = []
        func note(_ wait: Duration) {
            lock.withLock { waits.append(wait) }
        }
        var all: [Duration] { lock.withLock { waits } }
    }

    private func makeCore() -> (KiwiCore, () -> [String]) {
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true),
            authoritySpace(4, display: "UUID-A"),
        ]
        let core = makeAuthorityCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        core.desktopMemory.readWindowSpace = { _ in .hosted(4) }
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        return (core, { logs })
    }

    /// Files `id` as away, through the vanish the ledger records.
    private func fileAway(_ core: KiwiCore, _ id: UInt32) {
        core.eventLoop.onEvent(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: 100,
                    appName: "App100",
                    appBundleID: "app.test.100"
                )
            )
        )
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(id), wasMinimized: false)
        )
    }

    @Test("a destroy the compositor confirms prunes the entry")
    func confirmedDestroyPrunes() {
        defer { resetAuthorityOverrides() }
        let (core, _) = makeCore()
        defer { core.deferred.cancelAll() }
        fileAway(core, 7)
        #expect(core.state.awayWindows[WindowID(7)] != nil)
        core.desktopMemory.readWindowSpace = { _ in .gone }
        core.windowServerChanged(.destroyed, id: WindowID(7))
        #expect(core.deferred.isScheduled(.awayDestroyCheck))
        core.pruneDestroyedAway()
        #expect(core.state.awayWindows[WindowID(7)] == nil)
    }

    @Test("a window still hosted is left to the census")
    func hostedIsKept() {
        defer { resetAuthorityOverrides() }
        let (core, logs) = makeCore()
        defer { core.deferred.cancelAll() }
        fileAway(core, 7)
        core.windowServerChanged(.destroyed, id: WindowID(7))
        core.pruneDestroyedAway()
        #expect(core.state.awayWindows[WindowID(7)] != nil)
        #expect(logs().contains { $0.hasPrefix("away: w7 still") })
    }

    @Test("a destroy of a window not away owes no check")
    func otherDestroyOwesNothing() {
        defer { resetAuthorityOverrides() }
        let (core, _) = makeCore()
        defer { core.deferred.cancelAll() }
        core.windowServerChanged(.destroyed, id: WindowID(9))
        #expect(!core.deferred.isScheduled(.awayDestroyCheck))
        #expect(core.desktopMemory.awayDestroyed.isEmpty)
    }

    @Test(
        "the census backs off while WindowServer reports destroys",
        arguments: [true, false]
    )
    func cadenceFollowsTheRoute(live: Bool) async {
        defer { resetAuthorityOverrides() }
        let (core, _) = makeCore()
        defer { core.deferred.cancelAll() }
        fileAway(core, 7)
        core.deferred.cancel(.awayCensus)
        let sleeps = Sleeps()
        core.deferred.sleep = { wait in
            sleeps.note(wait)
            try? await Task.sleep(for: .seconds(3_600))
        }
        core.windowCreates.isLive = live
        core.scheduleAwayCensus()
        #expect(core.deferred.isScheduled(.awayCensus))
        for _ in 0..<100 where sleeps.all.isEmpty {
            await Task.yield()
        }
        let expected =
            live
            ? KiwiCore.awayBackstopInterval : KiwiCore.awayCensusInterval
        #expect(sleeps.all == [expected])
    }
}
