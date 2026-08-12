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
        return (recovery, dir)
    }

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
        second.bootTime = { .distantPast }
        second.captureState = {
            self.snapshot(at: Date(timeIntervalSince1970: 2000))
        }
        second.shutdownCleanly(preservingSession: true)

        // The arrangement the interrupted launch never restored is
        // still the one waiting for the next.
        let third = CrashRecovery(directory: dir)
        third.onLog = { _ in }
        third.bootTime = { .distantPast }
        #expect(third.consumeSession() == previous)
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
        second.bootTime = { .distantPast }
        var restored: StateSnapshot?
        second.restoreState = { restored = $0 }
        second.start()
        #expect(restored == sample)
        second.shutdownCleanly()
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
        second.bootTime = { .distantPast }
        var restored: StateSnapshot?
        second.restoreState = { restored = $0 }
        second.start()
        #expect(restored == nil)
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
        second.bootTime = {
            Date(timeIntervalSince1970: 2000)
        }
        second.captureState = { nil }
        var restored = false
        second.restoreState = { _ in restored = true }
        second.start()
        #expect(!restored)
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
