import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The logout freeze of the crash autosave (#1385): once a logout
/// begins, the window closes macOS performs must not overwrite the
/// last arrangement. Boot time and the freeze clock are injected.
@Suite("Logout autosave freeze", .serialized)
@MainActor
struct LogoutAutosaveFreezeTests {
    private let frozeAt = Date(timeIntervalSince1970: 9000)

    private func makeRecovery() throws -> (CrashRecovery, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-freeze-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let recovery = CrashRecovery(directory: dir)
        recovery.onLog = { _ in }
        recovery.workspaceCenter = NotificationCenter()
        let frozeAt = frozeAt
        recovery.now = { frozeAt }
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
            capturedAt: frozeAt
        )
    }

    /// What the next boot would restore from the autosave file.
    private func autosaved(in dir: URL) -> [UInt32]? {
        let reader = CrashRecovery(directory: dir)
        reader.onLog = { _ in }
        reader.bootTime = { .distantPast }
        return reader.takeBootSnapshot()?.windows.map(\.id)
    }

    @Test("Before the freeze an autosave writes; after it, none does")
    func freezeStopsTheWrite() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        let full = desk([1, 2, 3])
        let emptied = desk([1])
        recovery.captureState = { desk([1, 2]) }
        recovery.autosave()
        let before = autosaved(in: dir)
        #expect(before == [1, 2])
        recovery.captureState = { full }
        recovery.autosave()
        recovery.freezeForLogout()
        recovery.captureState = { emptied }
        recovery.autosave()
        let after = autosaved(in: dir)
        #expect(after == full.windows.map(\.id))
    }

    /// A cancelled logout posts nothing, so the freeze lifts past
    /// its bound; inside it every autosave still writes nothing.
    @Test("The freeze lifts past its bound and not before")
    func freezeLiftsPastItsBound() throws {
        let bound = CrashRecovery.logoutFreezeBound
        let kept = desk([1, 2])
        let later = desk([7])
        for (age, writes) in [(bound, false), (bound + 1, true)] {
            let (recovery, dir) = try makeRecovery()
            defer { try? FileManager.default.removeItem(at: dir) }
            recovery.captureState = { kept }
            recovery.autosave()
            recovery.freezeForLogout()
            let resumeAt = frozeAt.addingTimeInterval(age)
            recovery.now = { resumeAt }
            recovery.captureState = { later }
            recovery.autosave()
            let expected = (writes ? later : kept).windows.map(\.id)
            let read = autosaved(in: dir)
            #expect(read == expected)
        }
    }

    /// The wiring: `start()` hears the workspace's power-off
    /// notification on the injected center, and the timer's own
    /// write target then writes nothing.
    @Test("The power-off notification reaches the freeze")
    func notificationFreezesTheAutosave() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        let full = desk([4, 5])
        let emptied = desk([4])
        recovery.interval = 3600
        recovery.captureState = { full }
        recovery.start()
        defer { recovery.shutdownCleanly(preservingSession: true) }
        recovery.workspaceCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        let unfrozen = recovery.frozenAt
        #expect(unfrozen == nil)
        recovery.workspaceCenter.post(
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
        let frozen = recovery.frozenAt
        #expect(frozen == frozeAt)
        recovery.captureState = { emptied }
        recovery.autosave()
        let read = autosaved(in: dir)
        #expect(read == full.windows.map(\.id))
    }

    /// A logout ends in KiwiDesk's own clean stop, by when the
    /// desk is emptied: the stop writes no session over the
    /// pre-logout autosave and keeps that file for the next boot.
    @Test("A frozen clean stop keeps the pre-logout autosave")
    func frozenStopKeepsTheAutosave() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        let full = desk([1, 2, 3])
        recovery.captureState = { full }
        recovery.autosave()
        recovery.freezeForLogout()
        recovery.captureState = { desk([1]) }
        recovery.shutdownCleanly()
        let read = autosaved(in: dir)
        #expect(read == full.windows.map(\.id))
    }

    /// The stop removes the observer from the center `start()`
    /// added it on, whatever `workspaceCenter` names by then. The
    /// token is held so its release cannot stand in for a removal.
    @Test("The stop removes the observer from its own center")
    func stopRemovesFromTheAddingCenter() throws {
        let (recovery, dir) = try makeRecovery()
        defer { try? FileManager.default.removeItem(at: dir) }
        recovery.interval = 3600
        let added = recovery.workspaceCenter
        recovery.start()
        let token = try #require(recovery.powerOff?.token)
        recovery.workspaceCenter = NotificationCenter()
        recovery.shutdownCleanly(preservingSession: true)
        added.post(
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
        let frozen = recovery.frozenAt
        #expect(frozen == nil)
        withExtendedLifetime(token) {}
    }
}
