import Foundation

/// The `L(` call sites that interpolate another key's label —
/// the scan behind `InterpolatedLabelTests` (#818).
///
/// It lives in the `SourceScan+*` family rather than beside its
/// suite because `tests.md` puts source-scanning primitives
/// here: a second copy of a walker is how the over-matching copy
/// comes to swallow the very call sites its guard exists to
/// catch.
extension SourceScan {
    /// One discovered frame: the key it authors, and the keys of
    /// the controls it names, in specifier order.
    struct Frame {
        let key: String
        let labels: [String]
        /// Top-level arguments after the key and the English —
        /// i.e. how many specifiers the frame must carry. NOT
        /// `labels.count`: a ternary picks between two labels
        /// for ONE slot, which `layout.schematic.grid.ax` does,
        /// and counting keys reported it as a defect on this
        /// suite's first derived run.
        let slots: Int
        let file: String
    }

    /// Every `L(` call site in the GUI whose arguments contain a
    /// nested `L(` — parsed, not listed. Comments are stripped
    /// first: a commented-out call site standing in for a live
    /// one is the exact miss `gui.md` records from the Monitors
    /// run, and `guard-prover` re-proved it on a sibling suite in
    /// this same change set.
    static func interpolatingFrames() throws -> [Frame] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDesk")
        var frames: [Frame] = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let text = Array(source)
            var index = 0
            while index < text.count {
                guard
                    text[index] == "L",
                    index + 1 < text.count,
                    text[index + 1] == "("
                else {
                    index += 1
                    continue
                }
                var cursor = index + 1
                guard
                    let body = SourceScan.balanced(
                        text,
                        from: &cursor,
                        open: "(",
                        close: ")"
                    )
                else {
                    index += 1
                    continue
                }
                let keys = keyLiterals(in: body)
                // keys[0] is the frame's own key; the rest are
                // the nested L() arguments it interpolates.
                if keys.count > 1 {
                    frames.append(
                        Frame(
                            key: keys[0],
                            labels: Array(keys.dropFirst()),
                            slots: slotCount(in: body),
                            file: file.lastPathComponent
                        )
                    )
                }
                index = cursor
            }
        }
        return frames
    }

    /// The `L(` key literal of the body and of each nested `L(`,
    /// in source order. A key is the FIRST string literal after
    /// an `L(`, which is what `scripts/extract-keys` parses too.
    private static func keyLiterals(in body: String) -> [String] {
        var found: [String] = []
        let text = Array(body)
        var index = 0
        var wantKey = true  // the outer call's own key comes first
        while index < text.count {
            if wantKey, text[index] == "\"" {
                if let literal = literal(text, from: index) {
                    found.append(literal.value)
                    index = literal.end
                    wantKey = false
                    continue
                }
            }
            if text[index] == "L", index + 1 < text.count,
                text[index + 1] == "("
            {
                wantKey = true
                index += 2
                continue
            }
            index += 1
        }
        return found
    }

    /// Arguments after the key and the English literal, counted
    /// by top-level commas so a ternary, a nested call or a
    /// `+`-concatenated English all read as one argument each.
    private static func slotCount(in body: String) -> Int {
        let text = Array(body)
        var depth = 0
        var commas = 0
        var index = 0
        while index < text.count {
            if text[index] == "\"",
                let literal = literal(text, from: index)
            {
                index = literal.end
                continue
            }
            switch text[index] {
            case "(", "[": depth += 1
            case ")", "]": depth -= 1
            case "," where depth == 0: commas += 1
            default: break
            }
            index += 1
        }
        // key, English, then one argument per remaining comma.
        return max(0, commas - 1)
    }

    private static func literal(
        _ text: [Character],
        from start: Int
    ) -> (value: String, end: Int)? {
        guard start < text.count, text[start] == "\"" else {
            return nil
        }
        var index = start + 1
        var value = ""
        while index < text.count {
            if text[index] == "\\", index + 1 < text.count {
                // A key never contains an escape; an English
                // literal may, and we only need to skip past it.
                value.append(text[index])
                value.append(text[index + 1])
                index += 2
                continue
            }
            if text[index] == "\"" {
                return (value, index + 1)
            }
            value.append(text[index])
            index += 1
        }
        return nil
    }
}
