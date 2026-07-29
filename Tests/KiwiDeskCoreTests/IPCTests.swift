import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("NDJSON framing")
struct LineBufferTests {
    @Test("Reassembles split lines")
    func splitLines() {
        var buffer = LineBuffer()
        #expect(
            buffer.append(Data("{\"command\"".utf8)) == []
        )
        let lines = buffer.append(
            Data(":\"focus\"}\n{\"a\":1}\npartial".utf8)
        )
        #expect(
            lines == ["{\"command\":\"focus\"}", "{\"a\":1}"]
        )
        #expect(buffer.append(Data("\n".utf8)) == ["partial"])
    }

    @Test("Empty lines are skipped")
    func emptyLines() {
        var buffer = LineBuffer()
        #expect(buffer.append(Data("\n\nx\n".utf8)) == ["x"])
    }
}

@Suite("IPC codecs")
struct CodecTests {
    @Test("CommandRequest decodes the contract format")
    func requestDecoding() throws {
        let json = """
            {"command": "focus", "args": ["left"]}
            """
        let request = try JSONDecoder().decode(
            CommandRequest.self,
            from: Data(json.utf8)
        )
        #expect(request.command == "focus")
        #expect(request.args == [.string("left")])
    }

    @Test("Args accept mixed types")
    func mixedArgs() throws {
        let json = """
            {"command": "set_gap_override", "args": [3, 0]}
            """
        let request = try JSONDecoder().decode(
            CommandRequest.self,
            from: Data(json.utf8)
        )
        #expect(request.args?.first?.intValue == 3)
    }

    @Test("Responses round-trip")
    func responseRoundTrip() throws {
        let response = CommandResponse.ok(
            .object(["mode": .string("bsp")])
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(
            CommandResponse.self,
            from: data
        )
        #expect(decoded == response)
    }
}

@Suite("Service manager")
struct ServiceManagerTests {
    @Test("LaunchAgent plist references the executable")
    func plistContent() {
        let plist = ServiceManager.plistContent(
            executable: "/Applications/KiwiDesk.app/X"
        )
        #expect(
            plist.contains(
                "<string>/Applications/KiwiDesk.app/X"
                    + "</string>"
            )
        )
        #expect(plist.contains(ServiceManager.label))
        #expect(plist.contains("RunAtLoad"))
    }
}

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
        // Every name unknown means the empty set falls through
        // to the firehose, which is the more misleading of the
        // two outcomes and says so.
        #expect(
            logs.last?.contains("streaming all events") == true
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

    /// Blocking client work happens off the main actor; the
    /// server needs the main queue to process. The listener binds
    /// asynchronously, so connecting retries until it answers.
    private static func roundTrip(
        _ request: CommandRequest,
        over path: String
    ) async throws -> CommandResponse {
        try await Task.detached {
            () async throws -> CommandResponse in
            let deadline = Date().addingTimeInterval(
                socketConnectHangGuard
            )
            var client: SocketClient?
            while client == nil, Date() < deadline {
                client = try? SocketClient(path: path)
                if client != nil { break }
                try await Task.sleep(
                    nanoseconds: 20_000_000
                )
            }
            guard let client else {
                throw SocketError.connectFailed("timeout")
            }
            return try client.roundTrip(request)
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
