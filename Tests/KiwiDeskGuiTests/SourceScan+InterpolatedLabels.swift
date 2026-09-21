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
        /// Top-level arguments after the key and the English
        /// that carry a LABEL — a nested `L(` or a destination
        /// title — i.e. how many `%N$@` the frame must carry
        /// (#1117). Neither of the two neighbouring counts: not
        /// `labels.count`, since a ternary picks between two
        /// labels for ONE slot (`layout.schematic.grid.ax`), and
        /// not every argument, since a count rides `%N$d` and a
        /// frame passing a label beside two counts is correct
        /// with one `%N$@`.
        let labelSlots: Int
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
        let destinations = try destinationTitleKeys()
        var frames: [Frame] = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let text = Array(source)
            var index = 0
            while index < text.count {
                // Skip literals: an `L(` inside one would start a
                // balanced parse mid-string, invert quote parity
                // from there and then jump the cursor past
                // whatever it consumed — fail-open, real frames
                // silently unscanned.
                if text[index] == "\"",
                    let literal = literal(text, from: index)
                {
                    index = literal.end
                    continue
                }
                guard
                    text[index] == "L",
                    index + 1 < text.count,
                    text[index + 1] == "(",
                    isCallStart(text, at: index)
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
                let keys = keyLiterals(
                    in: body,
                    destinations: destinations
                )
                // keys[0] is the frame's own key; the rest are
                // the nested L() arguments it interpolates.
                if keys.count > 1 {
                    frames.append(
                        Frame(
                            key: keys[0],
                            labels: Array(keys.dropFirst()),
                            labelSlots: labelSlotCount(
                                in: body,
                                destinations: destinations
                            ),
                            file: file.lastPathComponent
                        )
                    )
                }
                index = cursor
            }
        }
        return frames
    }

    /// Whether the `L` at `index` starts a call rather than
    /// ending an identifier. Without this, `URL(` and
    /// `fileURL(` parse as `L(` — five live occurrences under
    /// `Sources/KiwiDesk` today. Harmless there because neither
    /// body yields two literals, but inside a real frame's
    /// argument list such a token re-arms the key hunt and the
    /// next literal registers as a "label".
    private static func isCallStart(
        _ text: [Character],
        at index: Int
    ) -> Bool {
        guard index > 0 else { return true }
        return !isIdentifier(text[index - 1], orDot: true)
    }

    /// The `L(` key literal of the body and of each nested `L(`,
    /// in source order. A key is the FIRST string literal after
    /// an `L(`, which is what `scripts/extract-keys` parses too.
    /// Literals are skipped between labels, so an `L(` spelled
    /// inside an English string cannot register.
    private static func keyLiterals(
        in body: String,
        destinations: [String: String]
    ) -> [String] {
        let text = Array(body)
        // The outer call's own key comes first.
        guard let opening = text.firstIndex(of: "\""),
            let key = literal(text, from: opening)
        else { return [] }
        var found = [key.value]
        var index = key.end
        while index < text.count {
            if text[index] == "\"",
                let literal = literal(text, from: index)
            {
                index = literal.end
                continue
            }
            if let hit = labelHit(
                text,
                at: index,
                destinations: destinations
            ) {
                found.append(hit.key)
                index = hit.end
                continue
            }
            index += 1
        }
        return found
    }

    /// A label at `index`, by the two shapes the scan knows: a
    /// nested `L(` whose first argument is its key literal, or a
    /// `SettingsDestination.<case>.title`. The ONE recogniser
    /// `keyLiterals` and `labelSlotCount` both walk with, so the
    /// derived labels and the label-slot count cannot disagree
    /// about what a label is (#1117) — a third shape lands in
    /// both or in neither. A nested `L(` whose key is not a
    /// literal (a variable) is not a label to either: its key
    /// cannot be read from source.
    private static func labelHit(
        _ text: [Character],
        at index: Int,
        destinations: [String: String]
    ) -> (key: String, end: Int)? {
        if text[index] == "L", index + 1 < text.count,
            text[index + 1] == "(",
            isCallStart(text, at: index)
        {
            var cursor = index + 2
            while cursor < text.count, text[cursor].isWhitespace {
                cursor += 1
            }
            guard cursor < text.count, text[cursor] == "\"",
                let key = literal(text, from: cursor)
            else { return nil }
            return (key.value, key.end)
        }
        return destinationTitle(
            text,
            at: index,
            destinations: destinations
        )
    }

    /// A `SettingsDestination.<case>.title` occurrence at
    /// `index`, and where it ends. Matched on the whole spelling
    /// so a bare `.title` on some other type cannot register.
    private static func destinationTitle(
        _ text: [Character],
        at index: Int,
        destinations: [String: String]
    ) -> (key: String, end: Int)? {
        let prefix = Array("SettingsDestination.")
        guard index + prefix.count < text.count,
            Array(text[index..<index + prefix.count]) == prefix,
            isCallStart(text, at: index)
        else { return nil }
        var cursor = index + prefix.count
        var name = ""
        while cursor < text.count,
            text[cursor].isLetter || text[cursor].isNumber
        {
            name.append(text[cursor])
            cursor += 1
        }
        let suffix = Array(".title")
        guard cursor + suffix.count <= text.count,
            Array(text[cursor..<cursor + suffix.count]) == suffix,
            let key = destinations[name]
        else { return nil }
        return (key, cursor + suffix.count)
    }

    /// The arguments after the key and the English that pass a
    /// label. Split at top-level commas so a ternary, a nested
    /// call or a `+`-concatenated English read as one argument
    /// each; an argument counts when `labelHit` finds a label in
    /// it — the one recogniser `keyLiterals` reads with too.
    private static func labelSlotCount(
        in body: String,
        destinations: [String: String]
    ) -> Int {
        let text = Array(body)
        var depth = 0
        var arguments: [[Character]] = [[]]
        var index = 0
        while index < text.count {
            if text[index] == "\"",
                let literal = literal(text, from: index)
            {
                arguments[arguments.count - 1]
                    .append(contentsOf: text[index..<literal.end])
                index = literal.end
                continue
            }
            switch text[index] {
            case "(", "[", "{": depth += 1
            case ")", "]", "}": depth -= 1
            case "," where depth == 0:
                arguments.append([])
                index += 1
                continue
            default: break
            }
            arguments[arguments.count - 1].append(text[index])
            index += 1
        }
        // key, English, then the interpolated arguments.
        return arguments.dropFirst(2).filter {
            carriesLabel($0, destinations: destinations)
        }.count
    }

    /// Whether one argument passes a label — `labelHit`'s
    /// verdict, literals skipped exactly as `keyLiterals` skips
    /// them.
    private static func carriesLabel(
        _ argument: [Character],
        destinations: [String: String]
    ) -> Bool {
        var index = 0
        while index < argument.count {
            if argument[index] == "\"",
                let literal = literal(argument, from: index)
            {
                index = literal.end
                continue
            }
            if labelHit(
                argument,
                at: index,
                destinations: destinations
            ) != nil {
                return true
            }
            index += 1
        }
        return false
    }

    /// Plain-quote walk: knows neither `"""` nor `#"…"#`, and is
    /// routed through `SourceScan.literalSpan` the day that bites
    /// (#1320), never widened here.
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
