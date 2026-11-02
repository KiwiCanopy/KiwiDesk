import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `kiwidesk subscribe` piped into a reader that exits early ends
/// with an error status instead of dying on SIGPIPE (#2870): the
/// entry ignores the signal, the line write throws, and the stream
/// stops on the throw.
@Suite("CLI broken pipe")
struct CLIBrokenPipeTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// One connection's worth of lines, then EOF.
    private final class Lines: CLILineSource {
        var lines: [String]
        init(_ lines: [String]) { self.lines = lines }
        func send(_ request: CommandRequest) throws {}
        func readLine() throws -> String? {
            lines.isEmpty ? nil : lines.removeFirst()
        }
    }

    /// A stream over `Lines`, counting its connections; it stops
    /// after three.
    private final class Counted {
        var connects = 0
        var stream: CLIEventStream {
            var stream = CLIEventStream()
            stream.connect = { [self] in
                connects += 1
                return Lines(["a", "b", "c"])
            }
            stream.pause = {}
            stream.note = { _ in }
            stream.keepGoing = { [self] in connects < 3 }
            return stream
        }
    }

    @Test("a reader gone ends the stream with 1, even reconnecting")
    func deliverFailureEnds() {
        struct Gone: Error {}
        for reconnect in [false, true] {
            let counted = Counted()
            var delivered: [String] = []
            let code = counted.stream.run(
                events: [],
                reconnect: reconnect
            ) {
                delivered.append($0)
                throw Gone()
            }
            #expect(code == 1)
            #expect(delivered == ["a"], "read on past a gone reader")
            #expect(counted.connects == 1, "reconnected past it")
        }
    }

    /// A revert of `writeLine` to the non-throwing write raises an
    /// uncaught exception here, which ends the test process rather
    /// than failing one test.
    @Test("subscribe into a closed pipe ends with 1, reconnecting")
    func subscribeIntoClosedPipe() throws {
        let pipe = Pipe()
        let write = pipe.fileHandleForWriting
        // Keeps the test runner itself out of SIGPIPE's way; the
        // CLI ignores the signal process-wide at its entry.
        _ = fcntl(write.fileDescriptor, F_SETNOSIGPIPE, 1)
        try pipe.fileHandleForReading.close()
        let counted = Counted()
        let code = CLIEventStream.subscribe(
            [CLIEventStream.reconnectFlag],
            stream: counted.stream,
            output: write
        )
        #expect(code == 1)
        #expect(counted.connects == 1, "reconnected past a gone reader")
    }

    @Test("the subscribe entry ignores SIGPIPE before streaming")
    func entryIgnoresSignal() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/CLIMain.swift"
            )
        )
        let arm = try #require(
            source.range(
                of: "if command == APIReference.socketOnlyCommand {"
            )
        )
        let body = String(source[arm.upperBound...].prefix(400))
        let ignore = try #require(
            body.range(of: "signal(SIGPIPE, SIG_IGN)")
        )
        let call = try #require(
            body.range(of: "CLIEventStream.subscribe(rest)")
        )
        #expect(ignore.upperBound <= call.lowerBound)
    }
}
