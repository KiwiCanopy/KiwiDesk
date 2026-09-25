import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A screen-count change waits for the topology to settle before
/// choosing a profile (#1612). The fixture replays the measured
/// Vision Pro disconnect: the built-in and the headset reported
/// together for ~0.3 s, then the built-in alone — a profile saved
/// for each shape, so the in-between report has one to load.
@Suite("Monitor change settle (#1612)", .serialized)
@MainActor
struct MonitorChangeSettleTests {
    private let builtIn = Display(
        id: DisplayID(1),
        name: "BUILTIN",
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
    private let headset = Display(
        id: DisplayID(44),
        name: "HEADSET",
        frame: CGRect(x: 100, y: 0, width: 200, height: 100)
    )

    /// A core with a two-screen profile `pair` and a one-screen
    /// profile `solo`, `solo` live on the built-in alone.
    private func makeCore(log: SettleLog) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-1612-\(UUID().uuidString)"
                )
        )
        core.handle(.displaysChanged([builtIn, headset]))
        core.execute("save_profile", args: [.string("pair")])
        core.handle(.displaysChanged([builtIn]))
        core.execute("save_profile", args: [.string("solo")])
        #expect(core.profiles.currentName == "solo")
        core.timings.monitorSettleDelay = .milliseconds(100)
        core.onLog = { log.lines.append($0) }
        return core
    }

    /// Awaits the pending settle, if any, to its end.
    private func settle(_ core: KiwiCore) async {
        await core.deferred.task(for: .monitorSettle)?.value
    }

    @Test("an in-between report loads nothing")
    func inBetweenReportLoadsNothing() async {
        let log = SettleLog()
        let core = makeCore(log: log)
        core.handle(.displaysChanged([builtIn, headset]))
        core.handle(.displaysChanged([builtIn]))
        await settle(core)
        #expect(core.profiles.currentName == "solo")
        #expect(!log.lines.contains { $0.contains("'pair'") })
    }

    @Test("an in-between round trip leaves the Space set as it was")
    func roundTripKeepsTheSpaces() async {
        let log = SettleLog()
        let core = makeCore(log: log)
        let before = core.state.workspaces.allSpaces.map(\.id)
        core.handle(.displaysChanged([builtIn, headset]))
        core.handle(.displaysChanged([builtIn]))
        await settle(core)
        // The heal seeded a Space for the headset in between; the
        // settle retires it rather than keeping a stray (#1612).
        #expect(core.state.workspaces.allSpaces.map(\.id) == before)
        #expect(core.healedSpaces.isEmpty)
    }

    @Test("a profile loaded inside the wait is not undone")
    func loadInsideTheWaitStands() async {
        let log = SettleLog()
        let core = makeCore(log: log)
        core.handle(.displaysChanged([builtIn, headset]))
        #expect(core.monitorSettlePending)
        core.execute("load_profile", args: [.string("solo")])
        #expect(!core.monitorSettlePending)
        await settle(core)
        #expect(core.profiles.currentName == "solo")
        #expect(!log.lines.contains { $0.contains("'pair'") })
    }

    @Test("a real count change decides once the reports stop")
    func realChangeDecidesAfterSettle() async {
        let log = SettleLog()
        let core = makeCore(log: log)
        core.handle(.displaysChanged([builtIn, headset]))
        #expect(core.profiles.currentName == "solo")
        #expect(core.deferred.isScheduled(.monitorSettle))
        await settle(core)
        #expect(core.profiles.currentName == "pair")
        #expect(
            log.lines.filter { $0.hasPrefix("monitor change:") }
                .count == 1
        )
        #expect(!core.deferred.isScheduled(.monitorSettle))
    }

    @Test("the Spaces re-home onto the new screens without waiting")
    func resolveDoesNotWait() {
        let log = SettleLog()
        let core = makeCore(log: log)
        core.handle(.displaysChanged([builtIn, headset]))
        #expect(core.deferred.isScheduled(.monitorSettle))
        // The #1175 heal: the arriving screen already holds a
        // Space before any profile is chosen.
        #expect(!core.state.workspaces.spaces(on: headset.id).isEmpty)
    }

    @Test("a gone screen's Spaces re-home without waiting")
    func disconnectResolvesNow() {
        let log = SettleLog()
        let core = makeCore(log: log)
        core.execute("load_profile", args: [.string("pair")])
        core.handle(.displaysChanged([builtIn, headset]))
        #expect(core.profiles.currentName == "pair")
        core.handle(.displaysChanged([builtIn]))
        #expect(core.monitorSettlePending)
        #expect(core.profiles.currentName == "pair")
    }

    @Test("a report while a settle is owed re-arms it, whatever the count")
    func pendingReportRearms() {
        let core = makeCore(log: SettleLog())
        core.handle(.displaysChanged([builtIn, headset]))
        core.handle(.displaysChanged([builtIn, headset]))
        #expect(core.monitorSettlePending)
        #expect(core.profiles.currentName == "solo")
    }

    @Test("monitor_change fires once, when the settle decides")
    func eventFiresOnceSettled() async {
        let core = makeCore(log: SettleLog())
        let events = EventCount()
        _ = core.bus.addSink { event, _ in
            if event == .monitorChange { events.count += 1 }
        }
        core.handle(.displaysChanged([builtIn, headset]))
        core.handle(.displaysChanged([builtIn]))
        #expect(events.count == 0)
        await settle(core)
        #expect(events.count == 1)
    }

    @Test("a load inside the wait still fires the owed event")
    func supersedeEmits() {
        let core = makeCore(log: SettleLog())
        let events = EventCount()
        _ = core.bus.addSink { event, _ in
            if event == .monitorChange { events.count += 1 }
        }
        core.handle(.displaysChanged([builtIn, headset]))
        core.execute("load_profile", args: [.string("solo")])
        #expect(events.count == 1)
    }

    @Test("windows move once: at the settle, never at the report")
    func oneRetileAtTheSettle() async {
        let core = makeCore(log: SettleLog())
        // Every pass rewrites the drawn-mode ledger (#1177).
        core.drawnSpaceModes = [:]
        core.handle(.displaysChanged([builtIn, headset]))
        core.handle(.displaysChanged([builtIn]))
        #expect(core.drawnSpaceModes.isEmpty)
        // Back to the live profile: no apply, so only the settle's
        // own retile can draw.
        await settle(core)
        #expect(!core.drawnSpaceModes.isEmpty)
    }

    @Test("a composed Standard applied inside the wait supersedes it")
    func composedSupersedes() {
        let core = makeCore(log: SettleLog())
        core.handle(.displaysChanged([builtIn, headset]))
        core.apply(
            composed: ProfileComposition.Composed(
                sourceName: "Std",
                spaces: [SpaceID(1)],
                spaceModes: [SpaceID(1): .bsp],
                assignment: [:],
                settings: TilingSettings()
            ),
            forceRetile: false
        )
        #expect(!core.monitorSettlePending)
    }

    @Test("a direct monitor-change decision supersedes a pending one")
    func directDecisionSupersedes() {
        let core = makeCore(log: SettleLog())
        core.handle(.displaysChanged([builtIn, headset]))
        core.handleMonitorChange()
        #expect(!core.monitorSettlePending)
    }

    @Test("a seed whose screen is live, or that holds a window, stays")
    func seedFilterKeepsLiveAndOccupied() {
        let core = makeCore(log: SettleLog())
        core.handle(.displaysChanged([builtIn, headset]))
        let seed = SpaceID(90)
        core.state.workspaces.ensureSpace(seed)
        core.healedSpaces[headset.fingerprint] = seed
        core.retireOrphanedHealSeeds()
        #expect(core.state.workspaces[seed] != nil)
        core.healedSpaces = ["GONE:1x1": seed]
        let window = WindowID(900)
        core.state.windows.upsert(
            ManagedWindow(id: window, pid: 1, appName: "Held")
        )
        core.state.workspaces.add(window, to: seed)
        core.retireOrphanedHealSeeds()
        #expect(core.state.workspaces[seed]?.windows == [window])
    }

    @Test("a same-count re-report decides at once")
    func sameCountIsImmediate() {
        let log = SettleLog()
        let core = makeCore(log: log)
        let moved = Display(
            id: DisplayID(1),
            name: "BUILTIN",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        core.handle(.displaysChanged([moved]))
        #expect(!core.deferred.isScheduled(.monitorSettle))
    }

    @Test("the first report after boot decides at once")
    func bootReportIsImmediate() {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-1612-boot-\(UUID().uuidString)"
                )
        )
        core.timings.monitorSettleDelay = .milliseconds(100)
        core.handle(.displaysChanged([builtIn]))
        #expect(!core.deferred.isScheduled(.monitorSettle))
    }
}

@MainActor
private final class EventCount {
    var count = 0
}

/// A reference sink for `onLog`, so the escaping closure and the
/// test read one array.
@MainActor
private final class SettleLog {
    var lines: [String] = []
}
