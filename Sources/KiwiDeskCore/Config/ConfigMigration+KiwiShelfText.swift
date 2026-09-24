import Foundation

/// The textual half of `migratingBarsOntoShelf`: edits a file
/// with ONE `settings` object whose bar groups are flat objects
/// of scalars, keeping every other byte — the value text the
/// shelf takes is copied, never re-encoded. Anything else stands
/// down to the walk; `surgicallyApplying` re-parses whatever this
/// returns against the walk, which is the net for a stray edit.
extension ConfigMigration {
    /// One `"key": scalar` pair of a flat object body: the text
    /// before its comma, and its key and value as written.
    struct ShelfPair {
        var text: String
        let key: String
        let value: String
    }

    static func surgicallyShelvedBars(_ text: String) -> Data? {
        guard count(of: "\"\(shelfSettingsKey)\"", in: text) == 1,
            count(of: "\"\(shelfKey)\"", in: text) == 0
        else { return nil }
        let pattern =
            "(\"(?:\(shelfSpaceBarKey)|\(shelfAppBarKey))\"\\s*:\\s*\\{)"
            + "([^{}]*)(\\})"
        guard let regex = try? NSRegularExpression(pattern: pattern)
        else { return nil }
        let whole = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: whole)
        // A layout's App Bar sits inside the one `layout` object;
        // every other App Bar match is the global one.
        guard let layout = objectSpan(ofKey: shelfLayoutKey, in: text)
        else { return nil }
        func inLayout(_ match: NSTextCheckingResult) -> Bool {
            layout.map { NSLocationInRange(match.range.location, $0) }
                ?? false
        }
        var spaceBar: [ShelfPair]?
        var globalApp: [ShelfPair]?
        for match in matches {
            guard let opener = Range(match.range(at: 1), in: text),
                let body = Range(match.range(at: 2), in: text),
                let pairs = shelfPairs(String(text[body]))?.pairs
            else { return nil }
            if text[opener].hasPrefix("\"\(shelfSpaceBarKey)\"") {
                guard spaceBar == nil else { return nil }
                spaceBar = pairs
            } else if !inLayout(match) {
                guard globalApp == nil else { return nil }
                globalApp = pairs
            }
        }
        // The walk's own choice, handed what the text says.
        let enabled = spaceBar?.first { $0.key == "enabled" }
            .map { ["enabled": $0.value != "false"] }
        let sourceIsSpaceBar =
            shelfSourceKey(spaceBar: enabled) == shelfSpaceBarKey
        let source = (sourceIsSpaceBar ? spaceBar : globalApp) ?? []
        let lacksIndicator =
            globalApp.map { bar in
                !bar.contains { $0.key == shelfIndicatorKey }
            } ?? false
        var out = text
        for match in matches.reversed() {
            guard let opener = Range(match.range(at: 1), in: out),
                let body = Range(match.range(at: 2), in: out),
                let parsed = shelfPairs(String(out[body]))
            else { return nil }
            let isSpaceBar = out[opener].hasPrefix(
                "\"\(shelfSpaceBarKey)\""
            )
            let isGlobalApp = !isSpaceBar && !inLayout(match)
            out.replaceSubrange(
                body,
                with: shelvedBody(
                    parsed,
                    isSpaceBar: isSpaceBar,
                    addsIndicator: isGlobalApp && lacksIndicator
                )
            )
        }
        let fullItem = globalApp?.first { $0.key == shelfItemColorKey }
        var entries = shelfMovedKeys.compactMap { key in
            source.first { $0.key == key }.map { pair in
                var value = pair.value
                if key == shelfItemColorKey, let fullItem,
                    isDimmedTwin(
                        unquoted(pair.value),
                        of: unquoted(fullItem.value)
                    )
                {
                    value = fullItem.value
                }
                return "\"\(key)\":\(value)"
            }
        }
        if !sourceIsSpaceBar,
            !source.contains(where: { $0.key == shelfEdgeKey })
        {
            entries.insert(
                "\"\(shelfEdgeKey)\":\"\(shelfAppBarOldEdge)\"",
                at: 0
            )
        }
        if !entries.isEmpty {
            let shelf =
                "\"\(shelfKey)\":{" + entries.joined(separator: ",")
                + "},"
            out = out.replacingOccurrences(
                of: "(\"\(shelfSettingsKey)\"\\s*:\\s*\\{)",
                with: "$1"
                    + NSRegularExpression.escapedTemplate(
                        for: shelf
                    ),
                options: .regularExpression
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }

    /// A bar body with the moved and dropped pairs gone and the
    /// Space Bar's title length renamed.
    static func shelvedBody(
        _ parsed: (pairs: [ShelfPair], tail: String),
        isSpaceBar: Bool,
        addsIndicator: Bool = false
    ) -> String {
        let stripped = Set(shelfMovedKeys + shelfDroppedKeys)
        var kept = parsed.pairs.filter { !stripped.contains($0.key) }
        for index in kept.indices
        where kept[index].key == shelfIndicatorKey
            && unquoted(kept[index].value) == shelfRetiredIndicator
        {
            kept[index].text = kept[index].text.replacingOccurrences(
                of: "\"\(shelfRetiredIndicator)\"",
                with: "\"\(shelfIndicatorFallback)\""
            )
        }
        if isSpaceBar {
            for index in kept.indices
            where kept[index].key == shelfRetiredTitleKey {
                kept[index].text = kept[index].text.replacingOccurrences(
                    of: "\"\(shelfRetiredTitleKey)\"",
                    with: "\"\(shelfFrontTitleKey)\""
                )
            }
        }
        var texts = kept.map(\.text)
        if addsIndicator {
            texts.append(
                "\"\(shelfIndicatorKey)\":\"\(shelfIndicatorFallback)\""
            )
        }
        return texts.joined(separator: ",") + parsed.tail
    }

    /// Splits a flat object body into its pairs and the
    /// whitespace before the closing brace; nil if any value is
    /// not a scalar or the body does not parse whole.
    static func shelfPairs(
        _ body: String
    ) -> (pairs: [ShelfPair], tail: String)? {
        let scalar =
            "\"(?:[^\"\\\\]|\\\\.)*\"|true|false|null"
            + "|-?[0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?"
        let pattern =
            "(\\s*\"([^\"\\\\]*)\"\\s*:\\s*(\(scalar)))(\\s*)(,?)"
        guard let regex = try? NSRegularExpression(pattern: pattern)
        else { return nil }
        var pairs: [ShelfPair] = []
        var cursor = body.startIndex
        var tail = ""
        while cursor < body.endIndex {
            let rest = NSRange(cursor..., in: body)
            guard
                let match = regex.firstMatch(
                    in: body,
                    options: .anchored,
                    range: rest
                ),
                let pair = Range(match.range(at: 1), in: body),
                let key = Range(match.range(at: 2), in: body),
                let value = Range(match.range(at: 3), in: body),
                let space = Range(match.range(at: 4), in: body),
                let comma = Range(match.range(at: 5), in: body),
                let all = Range(match.range, in: body)
            else {
                guard body[cursor...].allSatisfy(\.isWhitespace)
                else { return nil }
                tail = String(body[cursor...])
                break
            }
            pairs.append(
                ShelfPair(
                    text: String(body[pair]),
                    key: String(body[key]),
                    value: String(body[value])
                )
            )
            if comma.isEmpty {
                tail = String(body[space])
                cursor = all.upperBound
                guard cursor == body.endIndex else { return nil }
                break
            }
            cursor = all.upperBound
        }
        return (pairs, tail)
    }

    /// The character range of the object `key` opens, found by
    /// brace depth outside string literals: `.some(nil)` where no
    /// object has that key, nil where more than one does (the
    /// caller then stands down to the walk).
    static func objectSpan(
        ofKey key: String,
        in text: String
    ) -> NSRange?? {
        let pattern = "\"\(key)\"\\s*:\\s*\\{"
        guard let regex = try? NSRegularExpression(pattern: pattern)
        else { return nil }
        let utf16 = Array(text.utf16)
        let found = regex.matches(
            in: text,
            range: NSRange(location: 0, length: utf16.count)
        )
        guard found.count <= 1 else { return nil }
        guard let opener = found.first else { return .some(nil) }
        var index = opener.range.location + opener.range.length - 1
        var depth = 0
        var inString = false
        while index < utf16.count {
            let unit = utf16[index]
            if inString {
                if unit == 0x5C {
                    index += 1
                }  // backslash
                else if unit == 0x22 {
                    inString = false
                }
            } else if unit == 0x22 {
                inString = true
            } else if unit == 0x7B {
                depth += 1
            } else if unit == 0x7D {
                depth -= 1
                if depth == 0 {
                    let start = opener.range.location
                    return .some(
                        NSRange(location: start, length: index - start + 1)
                    )
                }
            }
            index += 1
        }
        return nil
    }

    /// A JSON string literal's contents; other scalars as written.
    static func unquoted(_ literal: String) -> String {
        guard literal.count >= 2, literal.hasPrefix("\""),
            literal.hasSuffix("\"")
        else { return literal }
        return String(literal.dropFirst().dropLast())
    }

    private static func count(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }
}
