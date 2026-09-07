import Foundation

/// The needles `LocalizedStaticStorageScan` reads with (#1311),
/// held apart because the scan file reached the 350-line ceiling.
///
/// `SourceScan.callSites` and `mentions` answer "does this occur"
/// and these answer WHERE, which is what telling a call from a
/// member read needs; `starts` is a second copy of
/// `SourceScan+Declarations`' private one with the opposite
/// `orDot`, named as a copy rather than left to look like reuse.
extension LocalizedStaticStorageTests {
    /// Whether `text` CALLS the free function `name` — the
    /// identifier followed by `(`, on a boundary, and not
    /// dot-prefixed, so a `Foo.L(` of someone else's never
    /// answers for ours.
    static func calls(
        _ name: String,
        in text: String
    ) -> Bool {
        occurrences(of: name, in: text, dotted: false).contains {
            next(after: $0, in: Array(text)) == "("
        }
    }

    /// Whether `text` READS the same-file member `name` — called
    /// (`label($0)`), qualified (`Self.title`) or bare.
    ///
    /// A member is not always a function: a computed `var`
    /// resolving `L()` is read without parentheses, and a
    /// call-only needle would leave every such indirection
    /// invisible. An argument LABEL is excluded — `label:` names
    /// a parameter, it does not read the member.
    static func references(
        _ name: String,
        in text: String
    ) -> Bool {
        let characters = Array(text)
        return occurrences(of: name, in: text, dotted: true)
            .contains { next(after: $0, in: characters) != ":" }
    }

    /// Offsets just past each boundary-clean occurrence of
    /// `name`. `dotted` keeps `.name`, which a member read has
    /// and a free call must not.
    private static func occurrences(
        of name: String,
        in text: String,
        dotted: Bool
    ) -> [Int] {
        let characters = Array(text)
        let needle = Array(name)
        var found: [Int] = []
        var index = 0
        while index + needle.count <= characters.count {
            defer { index += 1 }
            guard
                Array(characters[index..<(index + needle.count)])
                    == needle
            else { continue }
            if index > 0,
                SourceScan.isIdentifier(
                    characters[index - 1],
                    orDot: !dotted
                )
            {
                continue
            }
            let after = index + needle.count
            if after < characters.count,
                SourceScan.isIdentifier(characters[after], orDot: false)
            {
                continue
            }
            found.append(after)
        }
        return found
    }

    /// The first non-whitespace character at or after `offset`.
    private static func next(
        after offset: Int,
        in text: [Character]
    ) -> Character? {
        var index = offset
        while index < text.count, text[index].isWhitespace {
            index += 1
        }
        return index < text.count ? text[index] : nil
    }

    /// Whether `needle` begins at `index` on an identifier
    /// boundary.
    static func starts(
        _ text: [Character],
        at index: Int,
        _ needle: String
    ) -> Bool {
        let characters = Array(needle)
        guard index + characters.count <= text.count,
            Array(text[index..<(index + characters.count)])
                == characters
        else { return false }
        if index > 0,
            SourceScan.isIdentifier(text[index - 1], orDot: true)
        {
            return false
        }
        return true
    }
}
