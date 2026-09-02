import Foundation
import Testing

@testable import KiwiDeskCore

/// The away ledger (#1146): written on a compositor-confirmed
/// `vanished`, ended by the return, a census that no longer
/// hosts the id (the corrective `closed`), the app's exit and
/// the #634 reset. Process-global overrides, so serialized.
@MainActor
@Suite("The away ledger", .serialized)
struct AwayLedgerTests {
    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true),
            authoritySpace(4, display: "UUID-A"),
        ]
        let core = makeAuthorityCore()
        core.desktopMemory.readWindowSpace = { _ in .hosted(4) }
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        return core
    }

    private func window(_ id: UInt32, pid: pid_t = 100) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "App\(pid)",
            appBundleID: "app.test.\(pid)"
        )
    }

    /// A census hosting exactly `hosted` on space 4, away.
    private func census(hosting hosted: [UInt32]) -> DesktopCensus {
        DesktopCensus(
            hosts: Dictionary(
                uniqueKeysWithValues: hosted.map {
                    (
                        WindowID($0),
                        DesktopCensus.Host(space: 4, pid: 100, isUp: true)
                    )
                }
            ),
            shown: [1]
        )
    }

    @Test("a vanish files the window with the facts the fold erased")
    func vanishRecords() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: false)
        )
        let entry = core.state.awayWindows[WindowID(7)]
        #expect(entry?.pid == 100)
        #expect(entry?.appName == "App100")
        #expect(entry?.appBundleID == "app.test.100")
        #expect(entry?.nativeSpace == 4)
        #expect(core.state.rememberedSpace(of: WindowID(7)) == "1")
        #expect(core.awayMembers(of: "1") == [WindowID(7)])
    }

    @Test("a close files nothing")
    func closeRecordsNothing() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.desktopMemory.readWindowSpace = { _ in .gone }
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: false)
        )
        #expect(core.state.awayWindows.isEmpty)
    }

    @Test("a minimize and a transient overlay file nothing")
    func minimizeAndOverlayRecordNothing() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: true)
        )
        var overlay = window(8)
        overlay.isTransientOverlay = true
        core.eventLoop.onEvent(.windowCreated(overlay))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(8), wasMinimized: false)
        )
        #expect(core.state.awayWindows.isEmpty)
    }

    @Test("the return ends the entry")
    func returnClears() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: false)
        )
        #expect(core.state.awayWindows[WindowID(7)] != nil)
        core.eventLoop.onEvent(.windowCreated(window(7)))
        #expect(core.state.awayWindows[WindowID(7)] == nil)
    }

    @Test(
        "a census that no longer hosts the id prunes and reports closed once"
    )
    func pruneReportsClosed() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(.windowCreated(window(8)))
        for id: UInt32 in [7, 8] {
            core.eventLoop.onEvent(
                .windowDestroyed(WindowID(id), wasMinimized: false)
            )
        }
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in events.append((event, data)) }
        core.desktopMemory.readCensus = { _ in self.census(hosting: [8]) }
        core.refreshAwayWindows()
        #expect(core.state.awayWindows[WindowID(7)] == nil)
        #expect(core.state.awayWindows[WindowID(8)] != nil)
        #expect(core.state.rememberedSpace(of: WindowID(7)) == nil)
        let destroyed = events.filter { $0.0 == .windowDestroyed }
        #expect(destroyed.count == 1)
        if case .object(let payload)? = destroyed.first?.1 {
            #expect(payload["window_id"] == .number(7))
            #expect(payload["reason"] == .string("closed"))
            #expect(payload["space_id"] == .string("1"))
            #expect(payload["app"] == .string("App100"))
        }
        // A second refresh finds nothing to report.
        core.refreshAwayWindows()
        #expect(events.filter { $0.0 == .windowDestroyed }.count == 1)
    }

    @Test("no census leaves the ledger as it is and disarms the task")
    func noCensusIsNoVerdict() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: false)
        )
        core.desktopMemory.readCensus = { _ in nil }
        #expect(core.refreshAwayWindows() == false)
        #expect(core.state.awayWindows[WindowID(7)] != nil)
    }

    @Test(
        "a census updates parked, and a prune retires the focus memory"
    )
    func refreshUpdatesParkedAndRetiresFocus() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(.windowCreated(window(8)))
        core.desktopMemory.honoredFocus["1"] = [4: WindowID(8)]
        for id: UInt32 in [7, 8] {
            core.eventLoop.onEvent(
                .windowDestroyed(WindowID(id), wasMinimized: false)
            )
        }
        var parked = census(hosting: [7])
        parked = DesktopCensus(
            hosts: [
                WindowID(7): DesktopCensus.Host(
                    space: 4,
                    pid: 100,
                    isUp: false
                )
            ],
            shown: parked.shown
        )
        core.desktopMemory.readCensus = { _ in parked }
        #expect(core.refreshAwayWindows() == true)
        #expect(core.state.awayWindows[WindowID(7)]?.isUp == false)
        // Parked: known, drawn under no Space.
        #expect(core.awayMembers(of: "1").isEmpty)
        // Pruned: gone from the #1207 focus memory too.
        #expect(core.desktopMemory.honoredFocus["1"]?[4] == nil)
    }

    @Test("a prune retires both arrival debts naming the window")
    func pruneRetiresDebts() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(.windowCreated(window(8)))
        for id: UInt32 in [7, 8] {
            core.eventLoop.onEvent(
                .windowDestroyed(WindowID(id), wasMinimized: false)
            )
        }
        core.followFocus.record(WindowID(7))
        core.desktopMemory.returnFocus.record(WindowID(8))
        core.desktopMemory.readCensus = { _ in self.census(hosting: [8]) }
        core.refreshAwayWindows()
        #expect(core.followFocus.owed() == nil)
        // The other window's debt is untouched.
        #expect(core.desktopMemory.returnFocus.owed() == WindowID(8))
    }

    @Test("an exiting app's away windows retire their debts")
    func exitRetiresDebts() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: false)
        )
        core.desktopMemory.honoredFocus["1"] = [4: WindowID(7)]
        core.desktopMemory.returnFocus.record(WindowID(7))
        core.eventLoop.onEvent(.appTerminated(pid: 100))
        #expect(core.state.awayWindows.isEmpty)
        #expect(core.desktopMemory.honoredFocus["1"]?[4] == nil)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
    }

    @Test("the app's exit and the arrangement reset drop the entries")
    func exitAndResetDrop() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7, pid: 100)))
        core.eventLoop.onEvent(.windowCreated(window(9, pid: 200)))
        for id: UInt32 in [7, 9] {
            core.eventLoop.onEvent(
                .windowDestroyed(WindowID(id), wasMinimized: false)
            )
        }
        core.eventLoop.onEvent(.appTerminated(pid: 100))
        #expect(core.state.awayWindows[WindowID(7)] == nil)
        #expect(core.state.awayWindows[WindowID(9)] != nil)
        core.discardSavedArrangement()
        #expect(core.state.awayWindows.isEmpty)
    }

    @Test("a re-key moves the entry to the new id")
    func rekeyFollows() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.eventLoop.onEvent(.windowCreated(window(7)))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: false)
        )
        core.state.rekey(WindowID(7), to: WindowID(70))
        #expect(core.state.awayWindows[WindowID(7)] == nil)
        #expect(core.state.awayWindows[WindowID(70)]?.id == WindowID(70))
    }

    @Test("away members merge into a row by the rank they left at")
    func membersMergeByRank() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        for id: UInt32 in [1, 2, 3] {
            core.eventLoop.onEvent(.windowCreated(window(id)))
        }
        // The middle window departs; the row is [1, 3] now.
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        let row = core.state.workspaces["1"]?.windows ?? []
        #expect(row == [WindowID(1), WindowID(3)])
        #expect(
            core.withAwayMembers(row, of: "1")
                == [WindowID(1), WindowID(2), WindowID(3)]
        )
        // An unfiled entry joins no row.
        core.state.awayWindows[WindowID(50)] = AwayWindow(
            id: WindowID(50),
            pid: 100,
            appName: "App100",
            appBundleID: "app.test.100",
            nativeSpace: 4
        )
        #expect(core.awayMembers(of: "1") == [WindowID(2)])
        #expect(
            core.awayWindows(bundleID: "app.test.100").map(\.id)
                == [WindowID(2), WindowID(50)]
        )
    }
}
