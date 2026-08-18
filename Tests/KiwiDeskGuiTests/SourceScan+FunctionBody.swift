import Foundation
import Testing

/// The balanced-body walker the presence needles share: find
/// `func <name>(`, skip the balanced signature, return the
/// balanced `{…}` body of comment-stripped source. Extracted at
/// the third consumer (`OwnPidQueueNeedleTests`,
/// `SizeBoundGateNeedleTests`; `ZOrderSequenceWiringTests`
/// predates the extraction and keeps its private copy) on the
/// family's standing ground: harden the walk in one copy and
/// not another and the over-matching copy captures a signature
/// brace instead of the body — the drift its guard exists to
/// catch (the exact miss `ZOrderSequenceWiringTests`' own copy
/// was red-proved against, 2026-08-02).
extension SourceScan {
    /// The body of `function` in `file` under
    /// `Sources/KiwiDeskCore/<directory>`, or "" with a
    /// recorded issue — so a needle asserting on the result
    /// fails loudly rather than passing on an empty scan.
    static func functionBody(
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
        // Land ON the opening paren: `balanced` returns nil
        // without advancing when the cursor is not on its
        // opener, and a signature carrying a brace (a defaulted
        // closure parameter) would otherwise be captured as the
        // body.
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
}
