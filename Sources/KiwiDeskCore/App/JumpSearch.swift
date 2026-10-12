import Foundation

/// The ranking Jump to window filters by (#1875 ▸ Ruling), one
/// section at a time — open windows, minimized ones, hidden apps:
/// an app name that starts with the query, then one that contains
/// it, then a title word that starts with it, then a title that
/// contains it — each tier in the order the entries came, which
/// is most recently used first. A hidden-app row matches by name
/// alone. Case- and accent-insensitive; no fuzzy initials. Pure,
/// so the panel and its tests share it.
public enum JumpSearch {
    /// One surviving row and where its text matched — ranges into
    /// the entry's own `app` and `title`, never a folded copy.
    public struct Match: Sendable, Equatable {
        public let entry: JumpEntry
        public let appRange: Range<String.Index>?
        public let titleRange: Range<String.Index>?
    }

    /// `entries` filtered and ranked by `query`; every entry, in
    /// order and unmarked, for a query that is blank.
    public static func matches(
        _ entries: [JumpEntry],
        query: String
    ) -> [Match] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else {
            return entries.enumerated().sorted {
                let left = section($0.element)
                let right = section($1.element)
                return left != right ? left < right : $0.offset < $1.offset
            }.map {
                Match(entry: $0.element, appRange: nil, titleRange: nil)
            }
        }
        let ranked = entries.enumerated().compactMap {
            offset,
            entry -> (tier: Int, offset: Int, match: Match)? in
            guard let (tier, match) = rank(entry, needle) else {
                return nil
            }
            return (tier, offset, match)
        }
        return ranked.sorted {
            $0.tier != $1.tier ? $0.tier < $1.tier : $0.offset < $1.offset
        }.map(\.match)
    }

    /// The panel's sections in order — the window tiers, then hidden
    /// apps — each drawn under its own header, so no match quality
    /// lifts a row out of its section.
    private static func section(_ entry: JumpEntry) -> Int {
        entry.isHiddenApp
            ? JumpTier.minimized.rawValue + 1 : entry.tier.rawValue
    }

    /// The tier `entry` ranks in for `needle`, nil where nothing
    /// matches. Each section takes its own four tiers, after the
    /// sections ahead of it.
    private static func rank(
        _ entry: JumpEntry,
        _ needle: String
    ) -> (Int, Match)? {
        let floor = section(entry) * 4
        if let range = find(needle, in: entry.app) {
            let tier = range.lowerBound == entry.app.startIndex ? 0 : 1
            return (
                floor + tier,
                Match(entry: entry, appRange: range, titleRange: nil)
            )
        }
        guard !entry.isHiddenApp, let range = find(needle, in: entry.title)
        else {
            return nil
        }
        let word = wordStart(needle, in: entry.title)
        return (
            floor + (word == nil ? 3 : 2),
            Match(entry: entry, appRange: nil, titleRange: word ?? range)
        )
    }

    private static let options: String.CompareOptions = [
        .caseInsensitive, .diacriticInsensitive, .widthInsensitive,
    ]

    private static func find(
        _ needle: String,
        in text: String
    ) -> Range<String.Index>? {
        text.range(of: needle, options: options)
    }

    /// The first occurrence that begins a word: at the start, or
    /// after a character that is neither a letter nor a digit.
    private static func wordStart(
        _ needle: String,
        in text: String
    ) -> Range<String.Index>? {
        var from = text.startIndex
        while let range = text.range(
            of: needle,
            options: options,
            range: from..<text.endIndex
        ) {
            if range.lowerBound == text.startIndex
                || !text[text.index(before: range.lowerBound)]
                    .isLetterOrDigit
            {
                return range
            }
            from = text.index(after: range.lowerBound)
        }
        return nil
    }
}

extension Character {
    fileprivate var isLetterOrDigit: Bool { isLetter || isNumber }
}
