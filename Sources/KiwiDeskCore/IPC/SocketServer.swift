import Foundation
import Network

/// UNIX domain socket server for the CLI and external tools.
///
/// Protocol: newline-delimited JSON. Requests are
/// `CommandRequest`, responses `CommandResponse`. The special
/// `subscribe` command turns the connection into an event
/// stream (`EventMessage` per line).
@MainActor
public final class SocketServer {
    public typealias Handler =
        @MainActor (String, [JSONValue]) -> CommandResponse

    public var handler: Handler = { _, _ in
        .fail("server not wired")
    }
    public weak var bus: EventBus?
    public var onLog: @MainActor (String) -> Void = { _ in }

    private let path: String
    private var listener: NWListener?
    private var clients: [UUID: Client] = [:]

    public init(path: String) {
        self.path = path
    }

    public var isRunning: Bool { listener != nil }

    public func start() throws {
        guard listener == nil else { return }
        // Remove a stale socket from an unclean shutdown.
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
        listener.start(queue: .main)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        for client in clients.values {
            close(client)
        }
        clients = [:]
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Connections

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

    // MARK: - Requests

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
            subscribe(client, args: request.args ?? [])
            client.send(CommandResponse.ok())
            return
        }
        client.send(
            handler(request.command, request.args ?? [])
        )
    }

    private func subscribe(
        _ client: Client,
        args: [JSONValue]
    ) {
        let events = Set(
            args.compactMap { arg in
                arg.stringValue.flatMap {
                    KiwiNotification(rawValue: $0)
                }
            }
        )
        let wanted =
            events.isEmpty
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
