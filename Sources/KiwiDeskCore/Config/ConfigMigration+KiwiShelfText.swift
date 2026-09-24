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
        var spaceBar: [ShelfPair]?
        var appBars: [[ShelfPair]] = []
        for match in matches {
            guard let opener = Range(match.range(at: 1), in: text),
                let body = Range(match.range(at: 2), in: text),
                let pairs = shelfPairs(String(text[body]))?.pairs
            else { return nil }
            if text[opener].hasPrefix("\"\(shelfSpaceBarKey)\"") {
                guard spaceBar == nil else { return nil }
                spaceBar = pairs
            } else {
                appBars.append(pairs)
            }
        }
        // The walk's own choice, handed what the text says.
        let enabled = spaceBar?.first { $0.key == "enabled" }
            .map { ["enabled": $0.value != "false"] }
        let sourceIsSpaceBar =
            shelfSourceKey(spaceBar: enabled) == shelfSpaceBarKey
        // The global App Bar cannot be told from a layout's by
        // text alone once there are two.
        if !sourceIsSpaceBar && appBars.count > 1 { return nil }
        let source =
            (sourceIsSpaceBar ? spaceBar : appBars.first) ?? []
        // The global App Bar is the one beside the Space Bar; a
        // layout's may share its spelling, so name it only when
        // there is one — the walk decides every other shape.
        let globalApp = appBars.count == 1 ? appBars.first : nil
        if appBars.contains(where: { bar in
            !bar.contains { $0.key == shelfIndicatorKey }
        }) {
            return nil
        }
        var out = text
        for match in matches.reversed() {
            guard let opener = Range(match.range(at: 1), in: out),
                let body = Range(match.range(at: 2), in: out),
                let parsed = shelfPairs(String(out[body]))
            else { return nil }
            let isSpaceBar = out[opener].hasPrefix(
                "\"\(shelfSpaceBarKey)\""
            )
            out.replaceSubrange(
                body,
                with: shelvedBody(parsed, isSpaceBar: isSpaceBar)
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
        isSpaceBar: Bool
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
        return kept.map(\.text).joined(separator: ",") + parsed.tail
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
