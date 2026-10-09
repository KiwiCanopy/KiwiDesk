import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// File lifecycle and the boot-staleness gate (#633) of the
/// crash/session snapshot store (suite moved out of
/// `KeybindingTests.swift`, where it was misfiled). Boot time
/// is always injected (`bootTime`) so no test reads the host's
/// boot clock.
@Suite("Crash recovery", .serialized)
@MainActor
struct CrashRecoveryTests {
    private func makeRecovery() throws -> (CrashRecovery, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-crash-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let recovery = CrashRecovery(directory: dir)
        recovery.onLog = { _ in }
        recovery.loginSession = { 1 }
        // `start()` observes it; the shared workspace center is
        // process-global, so a test hands a private one (#1385).
        recovery.workspaceCenter = NotificationCenter()
        return (recovery, dir)
    }

    /// Unstamped, as a capture returns it: the writer stamps the
    /// login session, which this suite pins to 1 (#1385).
    private func snapshot(at date: Date) -> StateSnapshot {
        StateSnapshot(
            windows: [
                .init(
                    id: WindowID(1),
                    frame: CGRect(
                        x: 1,
                        y: 2,
                        width: 3,
                        height: 4
                    )
                )
            ],
            spaces: [],
            activeSpace: "1",
            capturedAt: date
        )
    }

    /// What a read returns for `snapshot`: the writer's stamp on it.
    private func stamped(_ snapshot: StateSnapshot) -> StateSnapshot {
        var stamped = snapshot
        stamped.loginSession = 1
        return stamped
    }

    /// A failed relaunch leaves an in-place snapshot for whatever
    /// launch comes next (#930): past the bound its session
    /// memory is dropped, the arrangement kept. Clock pinned.
    @Test("An old in-place snapshot keeps its arrangement, not sizing")
    func oldInPlaceSessionIsDropped() throws {
        let captured = Date(timeIntervalSince1970: 5000)
        var record = snapshot(at: captured)
        record.windows[0].session = StateSnapshot.WindowSession(
            sticky: .global,
            stickyReach: nil
        )
        let bound = CrashRecovery.inPlaceSessionBound
        for (age, keeps) in [(bound, true), (bound + 1, false)] {
            let (recovery, dir) = try makeRecovery()
            defer { try? FileManager.default.removeItem(at: dir) }
            recovery.captureInPlaceState = { record }
            recovery.shutdownCleanly(inPlace: true)
            let next = CrashRecovery(directory: dir)
            next.onLog = { _ in }
            next.loginSession = { 1 }
            next.bootTime = { .distantPast }
            next.now = { captured.addingTimeInterval(age) }
            let taken = try #require(next.takeBootSnapshot())
            #expect(taken.carriesSessions == keeps)
            #expect(taken.windows.map(\.id) == record.windows.map(\.id))
        }
    }

    @Test("Clean shutdown writes the session; consume is one-shot")
    func sessionRoundTrip() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        recovery.bootTime = { .distantPast }
        recovery.captureState = { self.snapshot(at: .now) }
        recovery.shutdownCleanly()
        let session = dir.appendingPathComponent(
            ".session_snapshot"
        )
        #expect(
            FileManager.default.fileExists(atPath: session.path)
        )
        #expect(recovery.consumeSession() != nil)
        #expect(
            !FileManager.default.fileExists(atPath: session.path)
        )
        #expect(recovery.consumeSession() == nil)
    }

    @Test("A session captured before this boot is discarded")
    func staleSessionDiscarded() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        var logged: [String] = []
        recovery.onLog = { logged.append($0) }
        recovery.captureState = {
            self.snapshot(at: Date(timeIntervalSince1970: 1000))
        }
        recovery.shutdownCleanly()
        recovery.bootTime = {
            Date(timeIntervalSince1970: 2000)
        }
        #expect(recovery.consumeSession() == nil)
        #expect(
            logged.contains {
                $0.contains("session snapshot predates")
            }
        )
    }

    @Test("A session captured at or after boot is kept")
    func freshSessionKept() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stamp = Date(timeIntervalSince1970: 5000)
        recovery.captureState = { self.snapshot(at: stamp) }
        recovery.shutdownCleanly()
        recovery.bootTime = { stamp }
        #expect(recovery.consumeSession() != nil)
    }

    /// A shutdown DURING boot must not write the session file.
    ///
    /// `shutdownCleanly` captures live state over it, and mid-scan
    /// that state is a fraction of the desk — written there it
    /// would overwrite the arrangement this launch had not
    /// restored yet, and the next launch would accept it (its
    /// `capturedAt` is after `kern.boottime`). Unreachable while
    /// boot was one synchronous block; a quit or a permission
    /// revoke at second 3 of a chunked scan reaches it (#801, code
    /// review 2026-08-12).
    @Test("A shutdown mid-boot keeps the previous session")
    func preservedSessionSurvivesShutdown() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        let previous = snapshot(
            at: Date(timeIntervalSince1970: 1000)
        )
        recovery.captureState = { previous }
        recovery.shutdownCleanly()

        // A second launch that stops mid-boot: live state is a
        // partial desk, and it must not land in the file.
        let second = CrashRecovery(directory: dir)
        second.onLog = { _ in }
        second.loginSession = { 1 }
        second.bootTime = { .distantPast }
        second.captureState = {
            self.snapshot(at: Date(timeIntervalSince1970: 2000))
        }
        second.shutdownCleanly(preservingSession: true)

        // The arrangement the interrupted launch never restored is
        // still the one waiting for the next.
        let third = CrashRecovery(directory: dir)
        third.onLog = { _ in }
        third.loginSession = { 1 }
        third.bootTime = { .distantPast }
        #expect(third.consumeSession() == stamped(previous))
    }

    @Test("Unclean shutdown restores the autosaved state")
    func uncleanRestore() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sample = snapshot(
            at: Date(timeIntervalSince1970: 1000)
        )
        recovery.captureState = { sample }
        recovery.autosave()

        // Simulate a crash: new instance, same directory.
        let second = CrashRecovery(directory: dir)
        second.onLog = { _ in }
        second.loginSession = { 1 }
        second.bootTime = { .distantPast }
        #expect(second.takeBootSnapshot() == stamped(sample))
        // Consumed: the autosave that follows is this launch's.
        #expect(second.takeBootSnapshot() == nil)
        second.shutdownCleanly()
    }

    /// A crash autosave newer than a session file wins, and the
    /// older session loses (#930): the newer arrangement is the
    /// one the user last saw.
    @Test("The newer of session and crash autosave is restored")
    func newerBootSnapshotWins() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        let older = snapshot(at: Date(timeIntervalSince1970: 1000))
        let newer = snapshot(at: Date(timeIntervalSince1970: 2000))
        recovery.captureState = { older }
        recovery.shutdownCleanly()
        recovery.captureState = { newer }
        recovery.autosave()
        let second = CrashRecovery(directory: dir)
        second.onLog = { _ in }
        second.loginSession = { 1 }
        second.bootTime = { .distantPast }
        #expect(second.takeBootSnapshot() == stamped(newer))

        let (third, thirdDir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: thirdDir) }
        // The other way round: an older autosave left beside a
        // newer session file loses to it.
        third.captureState = { older }
        third.autosave()
        third.captureState = { newer }
        let crashFile = thirdDir.appendingPathComponent(
            ".state_snapshot"
        )
        let kept = try Data(contentsOf: crashFile)
        third.shutdownCleanly()
        try kept.write(to: crashFile)
        let fourth = CrashRecovery(directory: thirdDir)
        fourth.onLog = { _ in }
        fourth.loginSession = { 1 }
        fourth.bootTime = { .distantPast }
        #expect(fourth.takeBootSnapshot() == stamped(newer))
    }

    @Test("Clean shutdown leaves nothing to restore")
    func cleanShutdown() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sample = snapshot(
            at: Date(timeIntervalSince1970: 1000)
        )
        recovery.captureState = { sample }
        recovery.autosave()
        recovery.shutdownCleanly()

        let second = CrashRecovery(directory: dir)
        second.onLog = { _ in }
        second.loginSession = { 1 }
        second.bootTime = { .distantPast }
        // The session file is the arrangement; no crash replay.
        #expect(second.takeBootSnapshot() == stamped(sample))
        #expect(second.takeBootSnapshot() == nil)
        second.shutdownCleanly()
    }

    @Test("A crash leftover from before this boot is dropped")
    func staleCrashLeftoverDropped() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        recovery.captureState = {
            self.snapshot(at: Date(timeIntervalSince1970: 1000))
        }
        recovery.autosave()
        let second = CrashRecovery(directory: dir)
        var logged: [String] = []
        second.onLog = { logged.append($0) }
        second.loginSession = { 1 }
        second.bootTime = {
            Date(timeIntervalSince1970: 2000)
        }
        second.captureState = { nil }
        #expect(second.takeBootSnapshot() == nil)
        let marker = dir.appendingPathComponent(
            ".state_snapshot"
        )
        #expect(
            !FileManager.default.fileExists(atPath: marker.path)
        )
        #expect(
            logged.contains {
                $0.contains("crash snapshot predates")
            }
        )
        second.shutdownCleanly()
    }

    @Test("start autosaves immediately, not at interval's end")
    func immediateAutosave() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        recovery.bootTime = { .distantPast }
        recovery.captureState = { self.snapshot(at: .now) }
        recovery.start()
        let marker = dir.appendingPathComponent(
            ".state_snapshot"
        )
        #expect(
            FileManager.default.fileExists(atPath: marker.path)
        )
        recovery.shutdownCleanly()
    }

    @Test("Clean shutdown drops the crash marker")
    func cleanShutdownDropsMarker() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        recovery.bootTime = { .distantPast }
        recovery.captureState = { self.snapshot(at: .now) }
        recovery.start()
        recovery.shutdownCleanly()
        let marker = dir.appendingPathComponent(
            ".state_snapshot"
        )
        #expect(
            !FileManager.default.fileExists(atPath: marker.path)
        )
    }
}
