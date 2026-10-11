import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Which files carry a stop across a boot or a login (#1864
/// ruling, 2026-10-09): a plain Quit's, once, when the next
/// session began inside `CrashRecovery.quitCrossingBound`, and a
/// logout freeze's — which now carries the hand floats as a stop's
/// capture does. Clocks and the login session are pinned.
@Suite("A Quit crosses a restart inside its bound (#1864)", .serialized)
@MainActor
struct QuitCrossingTests {
    private static let quitAt = Date(timeIntervalSince1970: 5000)

    private func directory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-quit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    private func recovery(
        in dir: URL,
        login: Int32,
        boot: Date,
        now: Date
    ) -> CrashRecovery {
        let recovery = CrashRecovery(directory: dir)
        recovery.onLog = { _ in }
        recovery.loginSession = { login }
        recovery.bootTime = { boot }
        recovery.now = { now }
        recovery.workspaceCenter = NotificationCenter()
        return recovery
    }

    private func desk(at date: Date) -> StateSnapshot {
        StateSnapshot(
            windows: [
                .init(
                    id: WindowID(1),
                    frame: CGRect(x: 1, y: 2, width: 300, height: 200)
                )
            ],
            spaces: [],
            activeSpace: "1",
            capturedAt: date
        )
    }

    /// Marks window 1 as a stop's capture marks a hand float.
    private static func carry(_ snapshot: StateSnapshot) -> StateSnapshot {
        var marked = snapshot
        marked.windows[0].floating = true
        return marked
    }

    /// The Quit, written by the first process.
    private func quit(in dir: URL) {
        let writer = recovery(
            in: dir,
            login: 1,
            boot: .distantPast,
            now: Self.quitAt
        )
        writer.captureState = { self.desk(at: Self.quitAt) }
        writer.stopCarry = Self.carry
        writer.shutdownCleanly()
    }

    @Test(
        "a Quit's file crosses a boot only inside the bound",
        arguments: [false, true]
    )
    func crossesABoot(late: Bool) throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        quit(in: dir)
        let bound = CrashRecovery.quitCrossingBound
        let boot = Self.quitAt.addingTimeInterval(late ? bound + 1 : bound)
        // The launch comes long after the boot: the boot decides.
        let next = recovery(
            in: dir,
            login: 1,
            boot: boot,
            now: boot.addingTimeInterval(3 * bound)
        )
        #expect(next.takeBootSnapshot() == nil)
        let crossing = next.takeCrossSessionCandidate()
        #expect((crossing != nil) == !late)
        #expect(crossing.map { $0.windows[0].floating == true } ?? late)
    }

    /// Within one boot the login's start is not readable, so the
    /// launch stands in for it.
    @Test(
        "a Quit's file crosses a login only inside the bound",
        arguments: [false, true]
    )
    func crossesALogin(late: Bool) throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        quit(in: dir)
        let bound = CrashRecovery.quitCrossingBound
        let next = recovery(
            in: dir,
            login: 2,
            boot: .distantPast,
            now: Self.quitAt.addingTimeInterval(late ? bound + 1 : bound)
        )
        #expect(next.takeBootSnapshot() == nil)
        #expect((next.takeCrossSessionCandidate() != nil) == !late)
    }

    /// The freeze writes back a kept autosave, marked as a stop's
    /// capture; the autosave's own file carries no hand float.
    @Test("the freeze's file carries the hand floats; an autosave none")
    func freezeCarriesHandFloats() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let writer = recovery(
            in: dir,
            login: 1,
            boot: .distantPast,
            now: Self.quitAt
        )
        writer.captureState = { self.desk(at: Self.quitAt) }
        writer.stopCarry = Self.carry
        let file = dir.appendingPathComponent(".state_snapshot")
        func read() throws -> StateSnapshot {
            try JSONDecoder().decode(
                StateSnapshot.self,
                from: Data(contentsOf: file)
            )
        }
        writer.autosave()
        #expect(try read().windows[0].floating == nil)
        writer.freezeForLogout()
        let frozen = try read()
        #expect(frozen.frozenForLogout)
        #expect(frozen.windows[0].floating == true)
    }
}
