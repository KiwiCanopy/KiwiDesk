import Foundation

/// The app's ONE search-matching predicate, shared by Settings
/// search and the app picker. `localizedStandardContains`
/// underneath, plus separator runs flattened on both sides — the
/// part it does not give you: German renders "Space Bar colors"
/// as "Space Bar-Farben", so typing `space bar farben` got
/// nothing. Deliberately NOT fuzzy: substring is predictable, and
/// a mistype gets no results rather than a confident wrong
/// answer.
extension String {
    /// Tests if string matches search query using normalized standard
    /// comparison.
    func searchMatches(_ query: String) -> Bool {
        searchNormalized
            .localizedStandardContains(query.searchNormalized)
    }

    /// Normalizes separator runs and whitespace into single spaces.
    var searchNormalized: String {
        components(separatedBy: Self.searchSeparators)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Explicit character set for separators preserving dots in bundle
    /// identifiers.
    private static let searchSeparators = CharacterSet(
        charactersIn: " \u{00a0}\t\n\u{000b}\u{000c}\r"
            + "-\u{2010}\u{2011}\u{2012}\u{2013}\u{2014}"
            + "\u{2015}\u{2212}"
    )
}
