import Foundation
import Testing

/// The own-process arm of the two per-app AX queues — a
/// production decision **no unit test can reach** (the
/// `ZOrderSequenceWiringTests` precedent): every suite
/// intercepts with `dispatchOverride` or severs the applier, so
/// deleting the arm leaves the whole tree green while an
/// in-process AX call lands on a background queue, where
/// AppKit serves it synchronously and traps (#426;
/// `FrameApplier.queue(for:)`'s comment carries the argument).
/// The Settings window tiles (#678 item 18) and the loop
/// observes its own pid, so both paths ARE reached in
/// production.
///
/// A **presence** scan: deleting the arm reds. It verifies the
/// arm exists, never that it is semantically right — that
/// argument lives on the arms themselves.
@Suite("Own-pid queue needles (#618)")
struct OwnPidQueueNeedleTests {
    private func body(
        of function: String,
        in file: String,
        under directory: String,
        _ path: StaticString = #filePath
    ) throws -> String {
        let url = SourceScan.repoRoot(from: "\(path)")
            .appendingPathComponent("Sources/KiwiDeskCore")
            .appendingPathComponent(directory)
            .appendingPathComponent(file)
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let characters = Array(source)
        let marker = Array("func \(function)(")
        guard
            let start = (0...(characters.count - marker.count))
                .first(where: { index in
                    Array(
                        characters[index..<(index + marker.count)]
                    ) == marker
                })
        else {
            Issue.record("\(function) not found in \(file)")
            return ""
        }
        var cursor = start + marker.count - 1
        guard
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            ) != nil
        else {
            Issue.record("\(function): signature not balanced")
            return ""
        }
        while cursor < characters.count,
            characters[cursor] != "{"
        {
            cursor += 1
        }
        return SourceScan.balanced(
            characters,
            from: &cursor,
            open: "{",
            close: "}"
        ) ?? ""
    }

    @Test("The frame-read queue keeps its own-pid main arm")
    func frameReadQueueKeepsOwnPidArm() throws {
        let source = try body(
            of: "queue",
            in: "FrameReadCoalescer.swift",
            under: "Events"
        )
        #expect(source.contains("pid == getpid()"))
        #expect(source.contains("return DispatchQueue.main"))
    }

    @Test("The frame-apply queue keeps its own-pid main arm")
    func frameApplyQueueKeepsOwnPidArm() throws {
        let source = try body(
            of: "queue",
            in: "FrameApplier.swift",
            under: "Tiling"
        )
        #expect(source.contains("pid == getpid()"))
        #expect(source.contains("return DispatchQueue.main"))
    }
}
