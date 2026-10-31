import Foundation
import Testing

@testable import KiwiDesk

/// `kiwidesk watch`'s launcher spawns a real child, so it lives in
/// the ExecTests partition (`MachineTouchTests`).
@Suite("ExecTests: CLI watch launcher")
struct ExecTestsCLIWatch {
    @Test("the launcher runs the command with its stdin and environment")
    func launcher() {
        let status = CLIWatchRunner.launch(
            [
                "sh", "-c",
                #"read l && test "$l" = hi && test "$KIWIDESK_EVENT" = e"#,
            ],
            ProcessInfo.processInfo.environment
                .merging(["KIWIDESK_EVENT": "e"]) { _, new in new },
            "hi"
        )
        #expect(status == 0)
        let missing = CLIWatchRunner.launch(
            ["kiwidesk-no-such-command"],
            ProcessInfo.processInfo.environment,
            "hi"
        )
        #expect(missing != 0)
    }

    @Test("a child that never reads costs the launcher no SIGPIPE")
    func childGoneBeforeWrite() {
        // Past the pipe buffer, so the write is still pending when
        // `true` exits and closes the read end (#2852).
        let status = CLIWatchRunner.launch(
            ["true"],
            ProcessInfo.processInfo.environment,
            String(repeating: "x", count: 1 << 20)
        )
        #expect(status == 0)
    }
}
