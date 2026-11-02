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

    @Test("a reader gone ends the stream with 1, even reconnecting")
    func deliverFailureEnds() {
        for reconnect in [false, true] {
            var connects = 0
            var stream = CLIEventStream()
            stream.connect = {
                connects += 1
                return CLIEventStreamTests.FakeSource(["a", "b", "c"])
            }
            stream.pause = {}
            stream.note = { _ in }
            stream.keepGoing = { connects < 3 }
            var delivered: [String] = []
            struct Gone: Error {}
            let code = stream.run(events: [], reconnect: reconnect) {
                delivered.append($0)
                throw Gone()
            }
            #expect(code == 1)
            #expect(delivered == ["a"], "read on past a gone reader")
            #expect(connects == 1, "reconnected past a gone reader")
        }
    }

    @Test("a line written to a closed pipe throws")
    func writeLineThrows() throws {
        let pipe = Pipe()
        let write = pipe.fileHandleForWriting
        // Keeps the test runner itself out of SIGPIPE's way; the
        // CLI ignores the signal process-wide at its entry.
        _ = fcntl(write.fileDescriptor, F_SETNOSIGPIPE, 1)
        try pipe.fileHandleForReading.close()
        #expect(throws: (any Error).self) {
            try CLIEventStream.writeLine("x", to: write)
        }
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
        let ignore = try #require(body.range(of: "signal(SIGPIPE, SIG_IGN)"))
        let call = try #require(
            body.range(of: "CLIEventStream.subscribe(rest)")
        )
        #expect(ignore.upperBound <= call.lowerBound)
    }
}
