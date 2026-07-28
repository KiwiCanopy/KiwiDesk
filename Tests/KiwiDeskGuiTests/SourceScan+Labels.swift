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
}
