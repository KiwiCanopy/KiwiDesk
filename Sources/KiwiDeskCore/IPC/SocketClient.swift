import Foundation

public enum SocketError: Error, Equatable {
    case pathTooLong
    case connectFailed(String)
    case sendFailed
    case closed
}

/// Blocking UNIX-socket client used by the CLI process.
///
/// Deliberately synchronous BSD sockets: the CLI sends one
/// request and reads one line (or streams events forever).
public final class SocketClient {
    private let fd: Int32
    private var buffer = Data()

    public init(path: String) throws {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let maxLength = MemoryLayout.size(
            ofValue: address.sun_path
        )
        guard path.utf8.count < maxLength else {
            throw SocketError.pathTooLong
        }
        withUnsafeMutableBytes(
            of: &address.sun_path
        ) { raw in
            path.utf8CString.withUnsafeBytes { source in
                raw.copyMemory(
                    from: UnsafeRawBufferPointer(
                        rebasing: source.prefix(maxLength)
                    )
                )
            }
        }

        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw SocketError.connectFailed("socket()")
        }
        let size = socklen_t(
            MemoryLayout<sockaddr_un>.size
        )
        let result = withUnsafePointer(to: &address) {
            pointer in
            pointer.withMemoryRebound(
                to: sockaddr.self,
                capacity: 1
            ) {
                connect(fd, $0, size)
            }
        }
        guard result == 0 else {
            // Do NOT close here: every stored property is
            // initialized by now, so a throwing class init still
            // runs deinit, whose close would then be the SECOND
            // close of this fd. Under concurrent fd churn the
            // number gets recycled — and a guarded reissue turns
            // the double close into an EXC_GUARD process kill
            // (#489: the test-runner crash). deinit owns the one
            // and only close.
            throw SocketError.connectFailed(
                String(cString: strerror(errno))
            )
        }
    }

    deinit {
        Darwin.close(fd)
    }

    public func send(_ request: CommandRequest) throws {
        var data = try JSONEncoder().encode(request)
        data.append(0x0A)
        let sent = data.withUnsafeBytes { raw in
            write(fd, raw.baseAddress, raw.count)
        }
        guard sent == data.count else {
            throw SocketError.sendFailed
        }
    }

    /// Blocks until one full line arrives (nil on EOF).
    public func readLine() throws -> String? {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let raw = buffer[
                    buffer.startIndex..<newline
                ]
                buffer.removeSubrange(
                    buffer.startIndex...newline
                )
                return String(data: raw, encoding: .utf8)
            }
            var chunk = [UInt8](repeating: 0, count: 65_536)
            let count = read(fd, &chunk, chunk.count)
            if count > 0 {
                buffer.append(
                    contentsOf: chunk[0..<count]
                )
            } else {
                return nil
            }
        }
    }

    /// Sends a request and decodes the single response line.
    public func roundTrip(
        _ request: CommandRequest
    ) throws -> CommandResponse {
        try send(request)
        guard let line = try readLine(),
            let data = line.data(using: .utf8)
        else {
            throw SocketError.closed
        }
        return try JSONDecoder().decode(
            CommandResponse.self,
            from: data
        )
    }
}
