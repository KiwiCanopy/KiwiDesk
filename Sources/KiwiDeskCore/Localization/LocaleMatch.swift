import Foundation

/// Picks the shipped locale that best serves the user's system
/// language preference — the "System default" half of the
/// language picker (issue #9).
///
/// Pure and actor-free on purpose: the inputs are both plain
/// string lists, so every case below is a unit test rather than a
/// machine whose System Settings have to be changed by hand.
enum LocaleMatch {
    /// The shipped locale to use, or `nil` for English.
    ///
    /// Walks `preferences` in the user's own priority order and
    /// takes the first that resolves, rather than consulting the
    /// top preference alone: a list of `["ca", "de", "en"]` ships
    /// no Catalan catalog but does want German ahead of English.
    ///
    /// A preference is a full BCP-47 tag (`zh-Hant-TW`, `de-AT`)
    /// while a catalog is named by language or by language plus
    /// script (`de`, `zh-Hant`), so a preference is resolved in
    /// two phases:
    ///
    /// 1. **exact**, most specific first, over the preference as
    ///    written and then its `maximalIdentifier` shortened one
    ///    subtag at a time — `de-AT` → `de-Latn-AT` → `de-Latn` →
    ///    `de`.
    /// 2. **widen**, and only if nothing matched exactly: the
    ///    bare language onto a catalog that refines it, `pt` →
    ///    `pt-BR`.
    ///
    /// The phases are ordered, not interleaved, and that is the
    /// whole subtlety. `maximalIdentifier` is what knows `zh-TW`
    /// implies Traditional (`zh-Hant-TW`); widening a bare `zh`
    /// answers **Simplified**. Widen at each truncation step
    /// instead of after all of them and a Taiwanese preference
    /// written the short way gets Simplified — not a coarser
    /// fallback, the wrong language.
    ///
    /// English short-circuits to `nil` wherever it sits in the
    /// list. It ships no catalog — English lives inline at the
    /// call sites — so without this an English-first user falls
    /// through to whatever their *second* language happens to be.
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
            // Widening is the last resort, and only on the bare
            // language: try it any earlier and `zh-TW` widens
            // onto Simplified before `zh-Hant-TW` is ever asked.
            if let hit = widen(language, in: available) {
                return hit
            }
        }
        return nil
    }

    /// The tags to try exactly, most specific first: the
    /// preference as written, then its maximal form shortened one
    /// subtag at a time (`zh-Hant-TW`, `zh-Hant`, `zh`).
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

    /// The alphabetically first catalog that refines `language`
    /// (`pt` → `pt-BR`), so the answer cannot depend on the order
    /// a directory listing happened to yield.
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
