import Foundation
import Testing

@testable import KiwiDesk

/// What the row HANDS the pin verdict (#1022). `AppRulePinTests`
/// holds the decisions and `AppRulePinWiringTests` that both
/// sites ask `pinVerdict`; neither sees the wrapper's inputs, so
/// `isOverride: false` removed the override tombstone from every
/// tiling row with the whole target green (guard-prover,
/// 2026-09-23). Split from `AppRulePinWiringTests` at the §2.1
/// ceiling; this suite watches the inputs, that one the call
/// sites.
@Suite("App rule pin verdict inputs (#1022)")
struct AppRulePinInputTests {
    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    /// The balanced body after `signature` in the row's facets
    /// file, comment-stripped — scoped so a neighbour spelling the
    /// same input cannot satisfy the clause.
    private func body(of signature: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/"
                    + "AppRuleRow+Facets.swift"
            )
        let raw = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let offset = try #require(
            raw.range(of: signature),
            "\(signature) is gone"
        )
        var cursor = raw.distance(
            from: raw.startIndex,
            to: offset.upperBound
        )
        let found = try #require(
            SourceScan.balanced(
                Array(raw),
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "\(signature) has no balanced body to read"
        )
        return Self.squashed(found)
    }

    @Test("the verdict is told whether the row is an override")
    func overrideReachesTheVerdict() throws {
        #expect(
            try body(
                of: "private func pinVerdict(floats: Bool) "
                    + "-> AppRulePin.Verdict"
            ).contains(
                Self.squashed("isOverride: overrideBase != nil")
            ),
            Comment(
                rawValue:
                    "the verdict no longer knows the row is an "
                    + "override — a tiling row there loses the "
                    + "clear button and re-pins on \"Tiles "
                    + "always\", so a profile cannot un-pin an app "
                    + "its base pins (#1022)"
            )
        )
    }

    @Test("an open pattern editor counts as floating")
    func composingCountsAsFloating() throws {
        #expect(
            try body(of: "var pinVerdict: AppRulePin.Verdict")
                .contains(
                    Self.squashed(
                        "floats: floatFacet != .never "
                            + "|| titlesEditing.wrappedValue"
                    )
                ),
            Comment(
                rawValue:
                    "a row composing its first title pattern is "
                    + "judged tiling — the clear button vanishes "
                    + "and the pin reads as required on an app "
                    + "the user is floating (#1022)"
            )
        )
    }
}
