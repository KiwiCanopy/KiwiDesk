import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Socket round-trip", .serialized)
@MainActor
struct SocketTests {
    @Test("Client command reaches the server handler")
    func roundTrip() async throws {
        let path = Self.throwawaySocketPath()
        let server = SocketServer(path: path)
        server.handler = { command, args in
            .ok(
                .object([
                    "echo": .string(command),
                    "count": .number(
                        Double(args.count)
                    ),
                ])
            )
        }
        try server.start()
        defer { server.stop() }

        let response = try await Self.roundTrip(
            CommandRequest(
                command: "focus",
                args: [.string("left")]
            ),
            over: path
        )

        #expect(response.isSuccess)
        #expect(
            response.data
                == .object([
                    "echo": .string("focus"),
                    "count": .number(1),
                ])
        )
    }

    /// A name that matches no event is dropped and the client
    /// still gets `ok`, so the subscription reads as working.
    /// The client made the mistake, so the response carries the
    /// list; `onLog` is the server's own record of it, and this
    /// is the seam's only caller.
    @Test("Unknown subscribe events reach the wire and the log")
    func unknownSubscribeEventsAreReported() async throws {
        let path = Self.throwawaySocketPath()
        let server = SocketServer(path: path)
        var logs: [String] = []
        server.onLog = { logs.append($0) }
        try server.start()
        defer { server.stop() }

        // The log lands before the `ok` is written, so awaiting
        // the response is the synchronisation — no poll, no
        // deadline on the assertion.
        let all = try await Self.roundTrip(
            CommandRequest(
                command: "subscribe",
                args: [.string("space_chnage")]
            ),
            over: path
        )
        #expect(all.isSuccess)
        #expect(
            all.data
                == .object([
                    "unknown": .array([.string("space_chnage")])
                ])
        )
        #expect(logs.count == 1)
        #expect(logs.last?.contains("space_chnage") == true)
        // Every name unknown leaves an empty filter, which is
        // not the no-filter request and so streams nothing.
        #expect(
            logs.last?.contains("nothing left to subscribe to")
                == true
        )

        // A non-string argument has no name to report but is
        // just as dropped, and a repeat is listed once.
        let mixed = try await Self.roundTrip(
            CommandRequest(
                command: "subscribe",
                args: [
                    .string("space_change"), .string("nope"),
                    .string("nope"), .bool(true),
                ]
            ),
            over: path
        )
        #expect(mixed.isSuccess)
        #expect(
            mixed.data
                == .object([
                    "unknown": .array([
                        .string("nope"), .string("<non-string>"),
                    ])
                ])
        )
        #expect(logs.count == 2)
        #expect(logs.last?.contains("ignored") == true)
    }

    /// The log is capped and the wire list is not, deliberately
    /// — the log's audience is chosen by whoever opened the
    /// socket, the response's is the client that just sent the
    /// names. Pinned because the asymmetry is exactly what a
    /// later reader "simplifies" by capping both.
    @Test("Many unknown events: log truncates, wire does not")
    func manyUnknownEventsTruncateOnlyTheLog() async throws {
        let path = Self.throwawaySocketPath()
        let server = SocketServer(path: path)
        var logs: [String] = []
        server.onLog = { logs.append($0) }
        try server.start()
        defer { server.stop() }

        let names = (1...6).map { "nope\($0)" }
        let response = try await Self.roundTrip(
            CommandRequest(
                command: "subscribe",
                args: names.map(JSONValue.string)
            ),
            over: path
        )
        #expect(
            response.data
                == .object([
                    "unknown": .array(names.map(JSONValue.string))
                ])
        )
        #expect(logs.last?.contains("nope5, …") == true)
        #expect(logs.last?.contains("nope6") == false)
    }

    /// An empty filter is not the no-filter request: a subscribe
    /// made entirely of typos used to fall through to the whole
    /// firehose, so the stream looked like it was working very
    /// hard rather than not at all.
    ///
    /// Proven without a sleep, by ordering. The emit runs on the
    /// main actor between two awaited round-trips, so a delivered
    /// event would already be queued **ahead** of the second
    /// response — and the second round-trip reads exactly one
    /// line. Getting a bare `ok` back is therefore proof the
    /// event was never sent, and the control below proves the
    /// emit reaches a client that did subscribe.
    @Test("An all-unknown subscribe streams nothing")
    func allUnknownSubscribeStreamsNothing() async throws {
        let path = Self.throwawaySocketPath()
        let server = SocketServer(path: path)
        let bus = EventBus()
        server.bus = bus
        try server.start()
        defer { server.stop() }
        let run = try await Task.detached {
            () async throws -> (CommandResponse, String?, String?) in
            let client = try await Self.connect(to: path)
            let deaf = try client.roundTrip(
                CommandRequest(
                    command: "subscribe",
                    args: [.string("space_chnage")]
                )
            )
            await MainActor.run {
                bus.emit(.spaceChange, data: .null, luaArgs: [])
            }
            // Control: the same client, now subscribed for real.
            // Read raw rather than decoded — if the emit above
            // was delivered, this line is the event, and saying
            // so beats a decoder complaining about a missing
            // `status` key.
            try client.send(
                CommandRequest(
                    command: "subscribe",
                    args: [.string("space_change")]
                )
            )
            let next = try client.readLine()
            await MainActor.run {
                bus.emit(.spaceChange, data: .null, luaArgs: [])
            }
            return (deaf, next, try client.readLine())
        }.value

        #expect(run.0.data != nil)
        #expect(run.1?.contains("\"status\"") == true)
        #expect(run.1?.contains("space_change") == false)
        #expect(run.2?.contains("\"space_change\"") == true)
    }

    @Test("A known subscribe event is silent and bare")
    func knownSubscribeEventIsQuiet() async throws {
        let path = Self.throwawaySocketPath()
        let server = SocketServer(path: path)
        var logs: [String] = []
        server.onLog = { logs.append($0) }
        try server.start()
        defer { server.stop() }

        let response = try await Self.roundTrip(
            CommandRequest(
                command: "subscribe",
                args: [.string("space_change")]
            ),
            over: path
        )
        #expect(response.isSuccess)
        #expect(response.data == nil)
        #expect(logs.isEmpty)
    }

    private static func throwawaySocketPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-\(UUID().uuidString.prefix(8)).sock"
            ).path
    }

    /// The listener binds asynchronously, so connecting retries
    /// until it answers. `nonisolated` because a client must
    /// never be held on the main actor: its reads block, and the
    /// server it is waiting on processes on the main queue.
    private nonisolated static func connect(
        to path: String
    ) async throws -> SocketClient {
        let deadline = Date().addingTimeInterval(
            socketConnectHangGuard
        )
        while Date() < deadline {
            if let client = try? SocketClient(path: path) {
                return client
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw SocketError.connectFailed("timeout")
    }

    /// Blocking client work happens off the main actor; the
    /// server needs the main queue to process.
    private static func roundTrip(
        _ request: CommandRequest,
        over path: String
    ) async throws -> CommandResponse {
        try await Task.detached {
            () async throws -> CommandResponse in
            try await connect(to: path).roundTrip(request)
        }.value
    }
}

/// The listener binds on the **main queue**, and swift-testing
/// runs suites concurrently, so under full-suite load the shared
/// main actor is starved for seconds and a tight deadline trips
/// on a connection that landed, just late (#344). Generous by
/// design: the loop exits the instant the socket answers — ~30 ms
/// in practice — so a passing run is never slowed and the
/// deadline only bounds a genuine hang.
private let socketConnectHangGuard: TimeInterval = 30
