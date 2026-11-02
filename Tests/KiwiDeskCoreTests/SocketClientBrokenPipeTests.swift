import Foundation
import Testing

@testable import KiwiDeskCore

/// A CLI socket whose app quits mid-send fails the send rather than
/// killing the process (#2870). Read off the connected socket's own
/// option: a real send to a closed peer without it would SIGPIPE
/// the test runner, taking every other suite's report with it.
@Suite("Socket client broken pipe")
struct SocketClientBrokenPipeTests {
    /// A bound, listening AF_UNIX socket a client can connect to
    /// before anything accepts.
    private func listener(at path: String) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        try #require(fd >= 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            path.utf8CString.withUnsafeBytes {
                raw.copyMemory(
                    from: UnsafeRawBufferPointer(
                        rebasing: $0.prefix(raw.count)
                    )
                )
            }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, size)
            }
        }
        try #require(bound == 0)
        try #require(listen(fd, 1) == 0)
        return fd
    }

    @Test("a connected client fails a send to a closed peer")
    func ignoresBrokenPipe() throws {
        let path =
            testTemporaryDirectory
            .appendingPathComponent(
                "pipe-\(UUID().uuidString.prefix(8)).sock"
            ).path
        let server = try listener(at: path)
        defer {
            close(server)
            unlink(path)
        }
        let client = try SocketClient(path: path)
        #expect(client.ignoresBrokenPipe)
    }
}
