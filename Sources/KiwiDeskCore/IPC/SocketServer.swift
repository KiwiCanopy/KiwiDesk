import Foundation
import Network

/// UNIX domain socket server for CLI and external tooling
/// (`core-boundaries.md`).
@MainActor
public final class SocketServer {
    public typealias Handler =
        @MainActor (String, [JSONValue]) -> CommandResponse

    public var handler: Handler = { _, _ in
        .fail("server not wired")
    }
    public weak var bus: EventBus?
    public var onLog: @MainActor (String) -> Void = CoreLog.write

    private let path: String
    private var listener: NWListener?
    private var clients: [UUID: Client] = [:]

    public init(path: String) {
        self.path = path
    }

    public var isRunning: Bool { listener != nil }

    /// A socket another process still answers on (#1881).
    public struct SocketInUse: Error, CustomStringConvertible {
        public let path: String
        public var description: String {
            "another process is listening on \(path)"
        }
    }

    public func start() throws {
        guard listener == nil else { return }
        // A live first instance's socket is never unlinked; a stale
        // file left by a crash is (#1881).
        if Self.isLive(path) { throw SocketInUse(path: path) }
        try? FileManager.default.removeItem(atPath: path)
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.unix(
            path: path
        )
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = {
            [weak self] connection in
            MainActor.assumeIsolated {
                self?.accept(connection)
            }
        }
        // The socket file only, owner-only once bound; never the
        // folder, which may be a dotfiles symlink (#1881).
        let path = self.path
        listener.stateUpdateHandler = { [weak self] state in
            guard case .ready = state, chmod(path, 0o600) != 0 else {
                return
            }
            MainActor.assumeIsolated {
                self?.onLog("socket: could not restrict \(path)")
            }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    /// Whether something accepts a connection on `path` — a plain
    /// AF_UNIX connect, which a stale file refuses at once. A path
    /// too long to probe reads as live.
    nonisolated static func isLive(_ path: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        // Too long to probe: refuse rather than unlink a live one.
        guard bytes.count < capacity else { return true }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: bytes)
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, size)
            }
        }
        return result == 0
    }

    public func stop() {
        // Only a server that bound the path removes it: a refused
        // start must not unlink the live socket on its quit (#1881).
        let bound = listener != nil
        listener?.cancel()
        listener = nil
        for client in clients.values {
            close(client)
        }
        clients = [:]
        if bound { try? FileManager.default.removeItem(atPath: path) }
    }

    private func accept(_ connection: NWConnection) {
        let client = Client(connection: connection)
        clients[client.id] = client
        client.onLine = { [weak self, weak client] line in
            guard let client else { return }
            self?.process(line, from: client)
        }
        client.onClosed = { [weak self, weak client] in
            guard let client else { return }
            self?.disconnect(client)
        }
        connection.start(queue: .main)
        client.receive()
    }

    private func disconnect(_ client: Client) {
        close(client)
        clients[client.id] = nil
    }

    private func close(_ client: Client) {
        if let token = client.sinkToken {
            bus?.removeSink(token)
        }
        client.connection.cancel()
    }

    private func process(_ line: String, from client: Client) {
        guard let data = line.data(using: .utf8),
            let request = try? JSONDecoder().decode(
                CommandRequest.self,
                from: data
            )
        else {
            client.send(CommandResponse.fail("invalid JSON"))
            return
        }
        if request.command == "subscribe" {
            let unknown = subscribe(
                client,
                args: request.args ?? []
            )
            client.send(
                unknown.isEmpty
                    ? CommandResponse.ok()
                    : CommandResponse.ok(
                        .object([
                            "unknown": .array(
                                unknown.map(JSONValue.string)
                            )
                        ])
                    )
            )
            return
        }
        client.send(
            handler(request.command, request.args ?? [])
        )
    }

    /// Subscribes client to requested notifications (`core-boundaries.md`).
    private func subscribe(
        _ client: Client,
        args: [JSONValue]
    ) -> [String] {
        var events: Set<KiwiNotification> = []
        var unknown: [String] = []
        // `seen` rather than `unknown.contains`: the 1 MB frame
        // can carry ~150k names, and a linear scan per name is
        // quadratic work on the main queue.
        var seen: Set<String> = []
        for arg in args {
            let name = arg.stringValue ?? "<non-string>"
            if let event = KiwiNotification(rawValue: name) {
                events.insert(event)
            } else if seen.insert(name).inserted {
                unknown.append(name)
            }
        }
        if !unknown.isEmpty {
            // Capped: names are client-supplied on an
            // unauthenticated socket, so an unbounded join lets
            // any local process write a line of any length into
            // the unified log. The RETURNED list is deliberately
            // uncapped — it echoes only what this client sent.
            let listed = unknown.prefix(5).joined(separator: ", ")
            let rest = unknown.count > 5 ? ", …" : ""
            onLog(
                "subscribe: unknown event(s) \(listed)\(rest)"
                    + (events.isEmpty
                        ? "; nothing left to subscribe to"
                        : "; ignored")
            )
        }
        // Empty filter means "everything" only for the request
        // that means it — NO arguments. Letting it also catch a
        // subscribe made entirely of typos handed back the whole
        // firehose. Asked of `args`, never reconstructed from the
        // accumulators above (review): they are equivalent only
        // while every argument lands in one of them.
        let wanted =
            args.isEmpty
            ? Set(KiwiNotification.allCases)
            : events
        if let old = client.sinkToken {
            bus?.removeSink(old)
        }
        client.sinkToken = bus?.addSink {
            [weak client] event, data in
            guard let client, wanted.contains(event) else {
                return
            }
            client.send(
                EventMessage(
                    event: event.rawValue,
                    data: data
                )
            )
        }
        return unknown
    }
}

/// One connected socket client.
@MainActor
private final class Client {
    let id = UUID()
    let connection: NWConnection
    var sinkToken: UUID?
    var onLine: @MainActor (String) -> Void = { _ in }
    var onClosed: @MainActor () -> Void = {}

    private var lines = LineBuffer()

    init(connection: NWConnection) {
        self.connection = connection
    }

    func receive() {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65_536
        ) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let data {
                    for line in self.lines.append(data) {
                        self.onLine(line)
                    }
                }
                if isComplete || error != nil {
                    self.onClosed()
                } else {
                    self.receive()
                }
            }
        }
    }

    func send(_ payload: some Encodable) {
        guard
            var data = try? JSONEncoder().encode(payload)
        else { return }
        data.append(0x0A)
        connection.send(
            content: data,
            completion: .contentProcessed { _ in }
        )
    }
}
