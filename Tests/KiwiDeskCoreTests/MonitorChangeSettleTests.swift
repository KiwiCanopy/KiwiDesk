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
        core.monitorSettleDelay = .milliseconds(100)
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
        // Space, and every Space resolves to a live screen.
        #expect(!core.state.workspaces.spaces(on: headset.id).isEmpty)
        for space in core.state.workspaces.allSpaces {
            let display = core.state.workspaces.display(of: space.id)
            #expect(display == builtIn.id || display == headset.id)
        }
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
        core.monitorSettleDelay = .milliseconds(100)
        core.handle(.displaysChanged([builtIn]))
        #expect(!core.deferred.isScheduled(.monitorSettle))
    }
}

/// A reference sink for `onLog`, so the escaping closure and the
/// test read one array.
@MainActor
private final class SettleLog {
    var lines: [String] = []
}
