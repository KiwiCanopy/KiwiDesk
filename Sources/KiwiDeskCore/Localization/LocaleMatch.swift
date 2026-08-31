import Foundation

/// Matches user system language preferences against shipped locale catalogs
/// (#9).
enum LocaleMatch {
    /// Shipped locale identifier to use, or `nil` for default English (#9).
    ///
    /// Evaluates candidate tags via exact BCP-47 match and
    /// maximal subtag reduction (`maximalIdentifier`), then widens
    /// the bare language. The phases are ORDERED, never
    /// interleaved: widen at each truncation step and `zh-TW` gets
    /// Simplified — not a coarser fallback, the wrong language.
    /// English short-circuits to nil wherever it sits: it ships no
    /// catalog, and falling through would hand an English-first
    /// user their second language.
    static func best(
        preferences: [String],
        available: [String]
    ) -> String? {
        for preference in preferences {
            let language =
                preference.split(separator: "-")
                .first.map(String.init) ?? preference
            if language.caseInsensitiveCompare("en")
                == .orderedSame
            {
                return nil
            }
            if let hit = exact(
                in: available,
                anyOf: candidates(for: preference)
            ) {
                return hit
            }
            if let hit = widen(language, in: available) {
                return hit
            }
        }
        return nil
    }

    /// Generates candidate tags ordered from most to least specific (#9).
    private static func candidates(
        for preference: String
    ) -> [String] {
        var tags = [preference]
        var subtags = Locale.Language(identifier: preference)
            .maximalIdentifier
            .split(separator: "-")
            .map(String.init)
        while !subtags.isEmpty {
            tags.append(subtags.joined(separator: "-"))
            subtags.removeLast()
        }
        return tags
    }

    private static func exact(
        in available: [String],
        anyOf tags: [String]
    ) -> String? {
        for tag in tags {
            if let hit = available.first(where: {
                $0.caseInsensitiveCompare(tag) == .orderedSame
            }) {
                return hit
            }
        }
        return nil
    }

    /// Alphabetically first catalog refining bare language code
    /// (e.g. `pt-BR`).
    private static func widen(
        _ language: String,
        in available: [String]
    ) -> String? {
        let refined = language.lowercased() + "-"
        return available.sorted().first {
            $0.lowercased().hasPrefix(refined)
        }
    }
}
