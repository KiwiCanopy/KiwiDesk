import Foundation
import Testing

@testable import KiwiDeskCore

/// The control socket stays its user's (#1881): a live socket is
/// never unlinked by a second server, a stale file is replaced,
/// and the bound socket file is owner-only.
@Suite("Socket ownership (#1881)", .serialized)
@MainActor
struct SocketServerOwnershipTests {
    /// The listener binds asynchronously and exposes no handle, so
    /// a wait polls under one generous hang guard (tests.md, #344).
    private let hangGuard: TimeInterval = 30

    private func throwawayPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-own-\(UUID().uuidString.prefix(8)).sock"
            ).path
    }

    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(hangGuard)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("a stale file is no live socket and is replaced")
    func staleFileIsReplaced() async throws {
        let path = throwawayPath()
        #expect(FileManager.default.createFile(atPath: path, contents: nil))
        #expect(!SocketServer.isLive(path))
        let server = SocketServer(path: path)
        try server.start()
        defer { server.stop() }
        await waitUntil { SocketServer.isLive(path) }
        #expect(SocketServer.isLive(path))
    }

    @Test("a second server never unlinks a live socket")
    func liveSocketIsKept() async throws {
        let path = throwawayPath()
        let first = SocketServer(path: path)
        try first.start()
        defer { first.stop() }
        await waitUntil { SocketServer.isLive(path) }
        let second = SocketServer(path: path)
        #expect(throws: SocketServer.SocketInUse.self) {
            try second.start()
        }
        #expect(!second.isRunning)
        // The refused server's quit leaves the live socket alone.
        second.stop()
        #expect(FileManager.default.fileExists(atPath: path))
        #expect(SocketServer.isLive(path))
    }

    @Test("the bound socket file is owner-only")
    func socketIsOwnerOnly() async throws {
        let path = throwawayPath()
        let server = SocketServer(path: path)
        try server.start()
        defer { server.stop() }
        func mode() -> Int? {
            let attributes = try? FileManager.default
                .attributesOfItem(atPath: path)
            return (attributes?[.posixPermissions] as? NSNumber)?
                .intValue
        }
        await waitUntil { mode() == 0o600 }
        #expect(mode() == 0o600)
    }
}
