import Foundation

/// The app's one search-matching predicate, shared by the sidebar
/// search and the app picker so "one search-matching vocabulary"
/// is a fact rather than a convention two files happen to follow.
///
/// `localizedStandardContains` underneath — Apple's user-facing
/// comparison, so matching is case- and diacritic-insensitive and
/// "grosse" finds "Größe" (verified, not assumed). On top of it,
/// **separator runs are flattened on both sides**, which is the
/// part `localizedStandardContains` does not give you.
///
/// That gap is not cosmetic. A compounding language hyphenates
/// exactly where a user types a space: German renders "Space Bar
/// colors" as "Space Bar-Farben", so someone reading the label and
/// typing what they see — `space bar farben` — got nothing. It bit
/// English too, before any translation existed: `per edge` missed
/// "Per-edge…". Both directions now work, and so does the reverse
/// (`app-bar` finds "App Bar").
///
/// Deliberately NOT fuzzy: no edit distance, no subsequence
/// matching, no dropped separators (`spacebar` still misses "Space
/// Bar"). Substring is predictable, and a user who mistypes gets
/// no results rather than a confident wrong answer — the
/// System Settings behaviour this whole surface imitates.
extension String {
    /// Whether `query` matches this string as a search subject.
    /// Both sides are normalized; neither is mutated for display,
    /// so a caller may still use the original text as an anchor id.
    func searchMatches(_ query: String) -> Bool {
        searchNormalized
            .localizedStandardContains(query.searchNormalized)
    }

    /// Separator runs — spaces, tabs, non-breaking spaces, and the
    /// whole hyphen/dash family — collapsed to one space, with the
    /// ends trimmed.
    var searchNormalized: String {
        components(separatedBy: Self.searchSeparators)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The hyphen family is spelled out rather than taken from
    /// `.punctuationCharacters`: a dot must NOT be a separator, or
    /// the app picker would stop distinguishing `com.apple.preview`
    /// from "com apple preview" — and its bundle-id matching is the
    /// reason an app stays findable by its habitual English name.
    private static let searchSeparators = CharacterSet(
        charactersIn: " \u{00a0}\t\n\u{000b}\u{000c}\r"
            + "-\u{2010}\u{2011}\u{2012}\u{2013}\u{2014}"
            + "\u{2015}\u{2212}"
    )
}
