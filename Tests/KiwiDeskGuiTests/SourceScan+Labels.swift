import Foundation

// Regex extraction shared by the source-scanning guards. The
// #277 part-1 walkers (`disclosureTitleKeys`,
// `sectionHeaderKeys`, `searchAnchorKeys`, `anchorSiteKeys`,
// `lKeys`) were retired with the hand-maintained index they
// guarded — the catalog guards (`SettingsCatalogSiteTests`,
// `SettingsCatalogArgumentTests`,
// `SettingsAnchorPrimitiveTests`) scan primitive call shapes
// and catalog references instead.
//
// Here rather than duplicated per suite for the reason this
// whole file exists (AGENTS.md §5): a copy hardened in one place
// and not the other over-matches, swallowing exactly the call
// sites its guard was meant to catch.
extension SourceScan {
    /// The FIRST capture of `pattern` in document order.
    /// Deliberately not "collect into a `Set` and take `first`"
    /// — a set's `first` is arbitrary order, which silently
    /// picks a random match while looking correct.
    static func firstMatch(
        in source: String,
        pattern: String
    ) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            ),
            let range = Range(match.range(at: 1), in: source)
        else { return nil }
        return String(source[range])
    }

    /// Every match's requested capture groups, in document
    /// order, a group that did not participate simply absent.
    /// The multi-group form of `allMatches`, for a pattern whose
    /// captures only mean something *together* — a property's
    /// name beside its type, where taking either alone pairs the
    /// wrong two.
    static func allMatchGroups(
        in source: String,
        pattern: String,
        groups: [Int],
        options: NSRegularExpression.Options = []
    ) -> [[Int: String]] {
        guard
            let regex = try? NSRegularExpression(
                pattern: pattern,
                options: options
            )
        else { return [] }
        let whole = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: whole).map {
            match in
            var found: [Int: String] = [:]
            for group in groups {
                guard group < match.numberOfRanges,
                    let range = Range(
                        match.range(at: group),
                        in: source
                    )
                else { continue }
                found[group] = String(source[range])
            }
            return found
        }
    }

    /// Every first capture of `pattern`, in document order.
    /// An array, not a `Set`: a guard that counts declarations
    /// needs to see a duplicate rather than have it silently
    /// collapse.
    static func allMatches(
        in source: String,
        pattern: String
    ) -> [String] {
        guard
            let regex = try? NSRegularExpression(pattern: pattern)
        else { return [] }
        return regex.matches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        )
        .compactMap { match in
            Range(match.range(at: 1), in: source)
                .map { String(source[$0]) }
        }
    }
}
