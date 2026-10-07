import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The login-session gate on both snapshot files (#1385): a logout
/// without a reboot passes the boot gate (#633) and reuses window
/// ids, so a file written in another login is dropped. Boot time,
/// the clock and the session are injected.
@Suite("Login session snapshot gate", .serialized)
@MainActor
struct LoginSessionGateTests {
    private let at = Date(timeIntervalSince1970: 9000)

    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-login-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    private func recovery(
        _ dir: URL,
        session: Int32?,
        log: @escaping @MainActor (String) -> Void = { _ in }
    ) -> CrashRecovery {
        let recovery = CrashRecovery(directory: dir)
        recovery.onLog = log
        recovery.workspaceCenter = NotificationCenter()
        recovery.bootTime = { .distantPast }
        let at = at
        recovery.now = { at }
        recovery.loginSession = { session }
        return recovery
    }

    private func desk(inPlace: Bool = false) -> StateSnapshot {
        let session = StateSnapshot.WindowSession(
            floating: true,
            sticky: .none,
            stickyReach: nil
        )
        return StateSnapshot(
            windows: [
                .init(
                    id: WindowID(7),
                    frame: CGRect(x: 0, y: 0, width: 10, height: 10),
                    session: inPlace ? session : nil
                )
            ],
            spaces: [],
            activeSpace: "1",
            capturedAt: at
        )
    }

    /// Writes one file under session 100 the way `kind` names.
    private func write(_ kind: String, in dir: URL) {
        let writer = recovery(dir, session: 100)
        writer.captureState = { self.desk() }
        if kind == "crash" {
            writer.autosave()
        } else {
            writer.shutdownCleanly()
        }
    }

    @Test(
        "A file from another login is dropped; this login's restores",
        arguments: ["crash", "session"]
    )
    func gateDropsAnotherLogin(kind: String) throws {
        for (reader, restores) in [(100, true), (200, false)] {
            let dir = try makeDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            write(kind, in: dir)
            var logged: [String] = []
            let boot = recovery(dir, session: Int32(reader)) {
                logged.append($0)
            }
            let read = boot.takeBootSnapshot()?.windows.map(\.id)
            #expect(read == (restores ? [7] : nil))
            let dropped = logged.contains {
                $0.contains("\(kind) snapshot is from another login")
            }
            #expect(dropped == !restores)
        }
    }

    /// The live read failing refuses a stamped file: the stake is
    /// replaying another login's ids, so the gate fails closed.
    @Test("An unreadable live session refuses a stamped file")
    func unreadableLiveSessionRefuses() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        write("crash", in: dir)
        let read = recovery(dir, session: nil).takeBootSnapshot()
        #expect(read == nil)
    }

    /// An older build stamps nothing. Its autosave and its plain
    /// stop are refused; its announced relaunch, in-place and
    /// inside `inPlaceSessionBound`, still restores.
    @Test("An unstamped file restores only as a young in-place one")
    func unstampedFileIsAnOlderBuilds() throws {
        let bound = CrashRecovery.inPlaceSessionBound
        let cases: [(String, Bool, TimeInterval, Bool)] = [
            (".state_snapshot", false, 0, false),
            (".session_snapshot", false, 0, false),
            (".session_snapshot", true, bound, true),
            (".session_snapshot", true, bound + 1, false),
        ]
        for (file, inPlace, age, restores) in cases {
            let dir = try makeDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            let unstamped = desk(inPlace: inPlace)
            #expect(unstamped.loginSession == nil)
            try JSONEncoder().encode(unstamped).write(
                to: dir.appendingPathComponent(file)
            )
            let boot = recovery(dir, session: 100)
            let readAt = at.addingTimeInterval(age)
            boot.now = { readAt }
            let read = boot.takeBootSnapshot()?.windows.map(\.id)
            #expect(read == (restores ? [7] : nil), "\(file) \(age)")
        }
    }

    /// The wiring: a fresh recovery stamps the host's audit
    /// session, which reads on this host and holds within it.
    @Test("The default stamp is the live audit session")
    func defaultStampIsTheLiveSession() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let live = try #require(LoginSession.current())
        #expect(LoginSession.current() == live)
        let fresh = CrashRecovery(directory: dir)
        fresh.onLog = { _ in }
        fresh.workspaceCenter = NotificationCenter()
        #expect(fresh.loginSession() == live)
        fresh.captureState = { self.desk() }
        fresh.autosave()
        let data = try Data(
            contentsOf: dir.appendingPathComponent(".state_snapshot")
        )
        let written = try JSONDecoder().decode(
            StateSnapshot.self,
            from: data
        )
        #expect(written.loginSession == live)
    }
}
