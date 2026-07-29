import Foundation

/// One place a needle matched in a scanned tree.
struct MachineTouchSite {
    let file: URL
    /// 1-based, so it reads like a compiler diagnostic.
    let line: Int

    var site: String { "\(file.lastPathComponent):\(line)" }
}

extension SourceScan {
    /// Every occurrence of `needle` under `directory`, comments
    /// stripped, where the character before the match is not an
    /// identifier character — so `KiwiCore(` matches neither
    /// `makeTestCore(` nor a hypothetical `MockKiwiCore(`.
    ///
    /// Backs `MachineTouchTests`: the machine-touch guards pin
    /// *construction sites* (a type name followed by `(`), and a
    /// plain substring count would let a wrapper type or factory
    /// suffix silently satisfy or evade the pin.
    static func identifierSites(
        of needle: String,
        under directory: URL
    ) throws -> [MachineTouchSite] {
        var found: [MachineTouchSite] = []
        for file in try swiftSources(under: directory) {
            let lines = stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            for index in lines.indices {
                let line = lines[index]
                var cursor = line.startIndex
                while let hit = line.range(
                    of: needle,
                    range: cursor..<line.endIndex
                ) {
                    defer { cursor = hit.upperBound }
                    if hit.lowerBound > line.startIndex {
                        let before = line[
                            line.index(
                                before: hit.lowerBound
                            )
                        ]
                        if before.isLetter || before.isNumber
                            || before == "_"
                        {
                            continue
                        }
                    }
                    found.append(
                        MachineTouchSite(
                            file: file,
                            line: index + 1
                        )
                    )
                }
            }
        }
        return found
    }

    /// The first `func <name>` in `file` — signature, parameter
    /// list and brace body — comments stripped, every line
    /// whitespace-trimmed, blank lines dropped: a normalized
    /// form two twin files can be compared by without
    /// hand-listing what they must contain. The parameter list
    /// is deliberately inside the comparison: `makeTestCore`'s
    /// no-op registrar is a *default argument*, so a twin that
    /// dropped it would differ in the signature, not the body.
    ///
    /// Returns nil when the function or its brace block cannot
    /// be found — a gap for the consumer to red on, never a
    /// silent skip.
    static func normalizedFunction(
        named name: String,
        in file: URL
    ) throws -> String? {
        let source = stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        guard let start = source.range(of: "func \(name)")
        else { return nil }
        let text = Array(source[start.lowerBound...])
        // Walk past the parameter list, then to the end of the
        // brace block; the normalized form is everything from
        // the `func` keyword through the closing brace.
        var cursor = 0
        while cursor < text.count, text[cursor] != "(" {
            cursor += 1
        }
        guard
            balanced(
                text,
                from: &cursor,
                open: "(",
                close: ")"
            ) != nil
        else { return nil }
        // The return arrow sits between `)` and `{`; balanced()
        // itself skips leading whitespace before `{`.
        while cursor < text.count, text[cursor] != "{" {
            cursor += 1
        }
        guard
            balanced(
                text,
                from: &cursor,
                open: "{",
                close: "}"
            ) != nil
        else { return nil }
        return String(text[0..<cursor])
            .split(
                separator: "\n",
                omittingEmptySubsequences: true
            )
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
