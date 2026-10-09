import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The logout freeze's rollback (#1385 ruling 2026-10-09): macOS
/// quits the apps before KiwiDesk hears the power-off, so at the
/// freeze a burst of CLOSES puts back the autosave written before
/// it. Hides, Desktop departures and a quiet freeze roll nothing
/// back. Every clock is the recovery's injected `now`.
@Suite("Logout autosave rollback", .serialized)
@MainActor
struct LogoutRollbackTests {
    private let start = Date(timeIntervalSince1970: 9000)

    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) {
            now = now.addingTimeInterval(seconds)
        }
    }

    private func makeRecovery(
        _ clock: Clock
    ) throws -> (CrashRecovery, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-rollback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let recovery = CrashRecovery(directory: dir)
        recovery.onLog = { _ in }
        recovery.loginSession = { 1 }
        recovery.workspaceCenter = NotificationCenter()
        recovery.now = { clock.now }
        return (recovery, dir)
    }

    private func desk(_ ids: [UInt32]) -> StateSnapshot {
        StateSnapshot(
            windows: ids.map {
                .init(
                    id: WindowID($0),
                    frame: CGRect(x: 0, y: 0, width: 10, height: 10)
                )
            },
            spaces: [],
            activeSpace: "1",
            capturedAt: start
        )
    }

    /// What the next boot reads from the autosave file.
    private func autosaved(in dir: URL) -> [UInt32]? {
        let reader = CrashRecovery(directory: dir)
        reader.onLog = { _ in }
        reader.loginSession = { 1 }
        reader.bootTime = { .distantPast }
        return reader.takeBootSnapshot()?.windows.map(\.id)
    }

    /// The measured restart's shape: a full autosave, closes, an
    /// autosave of the emptied desk, more closes, then the freeze.
    /// `closed` is each departure's verdict.
    private func logout(
        _ closed: [Bool],
        firstAfter: TimeInterval = 20
    ) throws -> [UInt32]? {
        let clock = Clock(start)
        let (recovery, dir) = try makeRecovery(clock)
        defer { try? FileManager.default.removeItem(at: dir) }
        recovery.captureState = { self.desk(Array(1...10)) }
        recovery.autosave()
        clock.advance(firstAfter)
        for verdict in closed.prefix(1) {
            recovery.noteDeparture(closed: verdict)
        }
        clock.advance(6)
        recovery.captureState = { self.desk([1, 2]) }
        recovery.autosave()
        for verdict in closed.dropFirst() {
            clock.advance(1)
            recovery.noteDeparture(closed: verdict)
        }
        clock.advance(2)
        recovery.freezeForLogout()
        return autosaved(in: dir)
    }

    @Test("A burst of closes before the freeze rolls back")
    func closesRollBack() throws {
        let read = try logout([true, true, true])
        #expect(read == Array(1...10))
    }

    @Test(
        "A hide or a Desktop departure in the window rolls nothing back",
        arguments: [[false, false], [true, false], [false, true]]
    )
    func nonClosesHoldTheFile(_ closed: [Bool]) throws {
        let read = try logout(closed)
        #expect(read == [1, 2])
    }

    @Test("A quiet freeze rolls nothing back")
    func quietFreezeKeepsTheFile() throws {
        let read = try logout([])
        #expect(read == [1, 2])
    }

    /// The window is the burst's: a close older than it is the
    /// user's own, and the autosave after it stands.
    @Test("A close older than the window rolls nothing back")
    func oldCloseIsNotTheBurst() throws {
        let window = LogoutRollback.burstWindow
        let inside = try logoutWithGap(window - 2)
        #expect(inside == Array(1...10))
        let stale = try logoutWithGap(window + 1)
        #expect(stale == [1, 2])
    }

    /// One close, then `gap` seconds before the freeze.
    private func logoutWithGap(_ gap: TimeInterval) throws -> [UInt32]? {
        let clock = Clock(start)
        let (recovery, dir) = try makeRecovery(clock)
        defer { try? FileManager.default.removeItem(at: dir) }
        recovery.captureState = { self.desk(Array(1...10)) }
        recovery.autosave()
        clock.advance(5)
        recovery.noteDeparture(closed: true)
        recovery.captureState = { self.desk([1, 2]) }
        recovery.autosave()
        clock.advance(gap)
        recovery.freezeForLogout()
        return autosaved(in: dir)
    }

    /// An autosave past the history bound is not rolled back to:
    /// nothing older than the bound stands for the desk.
    @Test("An autosave past the history bound is not rolled back to")
    func historyIsBounded() throws {
        let clock = Clock(start)
        let (recovery, dir) = try makeRecovery(clock)
        defer { try? FileManager.default.removeItem(at: dir) }
        recovery.captureState = { self.desk(Array(1...10)) }
        recovery.autosave()
        clock.advance(LogoutRollback.historyBound + 1)
        recovery.noteDeparture(closed: true)
        recovery.captureState = { self.desk([1, 2]) }
        recovery.autosave()
        clock.advance(1)
        recovery.freezeForLogout()
        #expect(autosaved(in: dir) == [1, 2])
    }

    /// The wiring: the gone handler hands its own verdict to the
    /// rollback — a minimize is no close — and a hide is none.
    @Test("The gone handler and the hide arm note their verdicts")
    func goneHandlerNotesItsVerdict() {
        let core = makeTestCore()
        let id = WindowID(41)
        let window = ManagedWindow(
            id: id,
            pid: 1,
            appName: "App",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        core.handle(.windowCreated(window))
        let minimized = core.handleWindowGone(
            id,
            wasMinimized: true,
            effects: AppliedEffects()
        )
        #expect(minimized == .minimized)
        #expect(core.crash.rollback.departures.last?.closed == false)
        let reason = core.handleWindowGone(
            id,
            wasMinimized: false,
            effects: AppliedEffects()
        )
        // Hosted nowhere and no Desktop switch: a close.
        #expect(reason == .closed)
        #expect(core.crash.rollback.departures.last?.closed == true)
        core.handle(.windowCreated(window))
        let before = core.crash.rollback.departures.count
        core.handle(.windowHidden(id))
        #expect(core.crash.rollback.departures.count == before + 1)
        #expect(core.crash.rollback.departures.last?.closed == false)
    }

    /// A logout quits whole apps: their windows leave through the
    /// exit, with no destroy, and still count as the burst.
    @Test("An app exit inside the window rolls back")
    func appExitsRollBack() throws {
        let clock = Clock(start)
        let core = makeTestCore()
        core.crash.now = { clock.now }
        for id in [UInt32(51), 52] {
            core.handle(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: 7,
                        appName: "App",
                        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
                    )
                )
            )
        }
        core.crash.captureState = { self.desk(Array(1...10)) }
        core.crash.autosave()
        clock.advance(20)
        core.handle(.appTerminated(pid: 7))
        #expect(core.crash.rollback.departures.map(\.closed) == [true, true])
        clock.advance(6)
        core.crash.captureState = { self.desk([1, 2]) }
        core.crash.autosave()
        clock.advance(2)
        core.crash.freezeForLogout()
        core.crash.bootTime = { .distantPast }
        let read = core.crash.takeBootSnapshot()
        #expect(read?.windows.map(\.id) == Array(1...10))
        #expect(read?.frozenForLogout == true)
    }

    /// The freeze marks the file it keeps, rolled back or not; an
    /// autosave and a Quit's stop mark nothing (#1385 ruling).
    @Test("Only the freeze marks a file for a later boot")
    func onlyTheFreezeMarks() throws {
        let clock = Clock(start)
        let (recovery, dir) = try makeRecovery(clock)
        defer { try? FileManager.default.removeItem(at: dir) }
        let reader = CrashRecovery(directory: dir)
        reader.onLog = { _ in }
        reader.loginSession = { 1 }
        reader.bootTime = { .distantPast }
        recovery.captureState = { self.desk([1, 2]) }
        recovery.autosave()
        #expect(reader.takeBootSnapshot()?.frozenForLogout == false)
        recovery.autosave()
        recovery.shutdownCleanly()
        #expect(reader.takeBootSnapshot()?.frozenForLogout == false)
        recovery.autosave()
        recovery.freezeForLogout()
        let frozen = reader.takeBootSnapshot()
        #expect(frozen?.frozenForLogout == true)
        #expect(frozen?.windows.map(\.id) == [1, 2])
    }

    /// A cancelled logout: the freeze lifts past its bound, and the
    /// first write after it replaces the marked file — an autosave
    /// with an unmarked one, a Quit with its session.
    @Test("The first write after a lifted freeze unmarks the file")
    func liftedFreezeUnmarks() throws {
        for quits in [false, true] {
            let clock = Clock(start)
            let (recovery, dir) = try makeRecovery(clock)
            defer { try? FileManager.default.removeItem(at: dir) }
            recovery.captureState = { self.desk([1, 2]) }
            recovery.autosave()
            recovery.freezeForLogout()
            clock.advance(CrashRecovery.logoutFreezeBound + 1)
            if quits {
                recovery.shutdownCleanly()
            } else {
                recovery.autosave()
            }
            let reader = CrashRecovery(directory: dir)
            reader.onLog = { _ in }
            reader.loginSession = { 1 }
            reader.bootTime = { .distantPast }
            let read = reader.takeBootSnapshot()
            #expect(read?.frozenForLogout == false, "quits: \(quits)")
        }
    }
}
