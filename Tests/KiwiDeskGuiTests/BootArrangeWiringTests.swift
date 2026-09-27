import Foundation
import Testing

/// The boot tail's half of #930 ruling 4 that no behavior suite
/// reaches: `finishBoot` is not test-drivable, so
/// `BootArrangesAfterRestoreTests` drives `arrangeBootDesk` and
/// these needles hold that the tail hands it the session and
/// draws nothing of its own ahead of it. Brace-anchored over
/// comment-stripped source, like `StartupSweepWiringTests`.
@Suite("Boot arrange wiring (#930)")
struct BootArrangeWiringTests {
    private func finishBootBody() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Boot.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        try #require(!text.isEmpty)
        let tail = #"func finishBoot\(\)[\s\S]{0,4000}?\n    \}"#
        return String(
            text[
                try #require(
                    text.range(of: tail, options: .regularExpression)
                )
            ]
        )
    }

    @Test("the boot tail arranges from the taken boot snapshot")
    func tailArrangesFromTheBootSnapshot() throws {
        let body = try finishBootBody()
        #expect(
            body.contains(
                "arrangeBootDesk(session: crash.takeBootSnapshot())"
            ),
            """
            The boot tail no longer hands the previous session — \
            a clean stop's or a crash's — to arrangeBootDesk, so \
            the scan's AX order is laid out instead.
            """
        )
    }

    /// The POSITION, not a list of forbidden spellings (tests.md,
    /// #1021): the arrangement is the tail's first statement
    /// after the scan's clock stamp and the deferral's release,
    /// so no pass — however spelled, or hidden in a callee — can
    /// run ahead of it.
    @Test("the arrangement is the tail's first act")
    func arrangementComesFirst() throws {
        let body = try finishBootBody()
        let arrange = try #require(
            body.range(of: "arrangeBootDesk(")
        )
        let open = try #require(body.range(of: "{"))
        let statements = body[open.upperBound..<arrange.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(
            statements == [
                "boot.scanDone = ContinuousClock.now",
                "defersEventRetiles = false",
            ],
            """
            Something runs ahead of arrangeBootDesk in the boot \
            tail: \(statements). A pass there tiles the scan's AX \
            order — a hidden Space's windows on screen — before \
            the session files them (#930).
            """
        )
    }
}
