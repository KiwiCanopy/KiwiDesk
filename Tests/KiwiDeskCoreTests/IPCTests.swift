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
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-\(UUID().uuidString.prefix(8)).sock"
            ).path
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

        // Blocking client work happens off the main actor;
        // the server needs the main queue to process. The
        // listener binds asynchronously, so connecting may
        // need a few retries.
        let response = try await Task.detached {
            () async throws -> CommandResponse in
            var client: SocketClient?
            for _ in 0..<50 {
                client = try? SocketClient(path: path)
                if client != nil { break }
                try await Task.sleep(
                    nanoseconds: 20_000_000
                )
            }
            guard let client else {
                throw SocketError.connectFailed("timeout")
            }
            return try client.roundTrip(
                CommandRequest(
                    command: "focus",
                    args: [.string("left")]
                )
            )
        }.value

        #expect(response.isSuccess)
        #expect(
            response.data
                == .object([
                    "echo": .string("focus"),
                    "count": .number(1),
                ])
        )
    }
}
