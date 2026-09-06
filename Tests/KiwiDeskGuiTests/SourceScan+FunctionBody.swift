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
        let source = try SourceScan.strippedSource(at: url)
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

extension SourceScan {
    /// `declaration`'s own balanced body, taken from already-read
    /// SOURCE TEXT rather than from a `KiwiDeskCore` path — the
    /// sibling of `functionBody(of:in:under:)` for the GUI tree,
    /// and for a scan that has its own file in hand.
    ///
    /// Extracted at the second consumer (#1235), on the
    /// divergence ground `tests.md` names: `guard-prover` beat
    /// four clauses of the #1240 suite that read a whole FILE
    /// instead of their subject, so a copy that scoped less
    /// would restore exactly that hole while reading as though
    /// it did not. `open`/`close` because one caller scopes a
    /// declaration by braces and another an argument list by
    /// parentheses.
    static func declarationBody(
        of declaration: String,
        in source: String,
        open: Character = "{",
        close: Character = "}"
    ) -> String? {
        let text = Array(source)
        let marker = Array(declaration)
        guard text.count >= marker.count else { return nil }
        guard
            let head = (0...(text.count - marker.count)).first(
                where: { index in
                    Array(text[index..<(index + marker.count)])
                        == marker
                }
            )
        else { return nil }
        // Past the signature to the declaration's own opener — a
        // `func` carries a parameter list between the two.
        var cursor = head + marker.count
        while cursor < text.count, text[cursor] != open {
            cursor += 1
        }
        return balanced(
            text,
            from: &cursor,
            open: open,
            close: close
        )
    }
}
