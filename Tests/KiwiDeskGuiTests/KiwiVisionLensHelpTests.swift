import Foundation
import Testing

@testable import KiwiDesk

/// A lens's override rows (#3176): each wears its Default-page row's
/// `?` through `OverrideChrome`, so it stays clickable while the row
/// follows Default, and "Unchecked rows follow Default." captions
/// the whole form above its four cards. Source scans only.
@Suite("KiwiVision lens rows' help (#3176)")
struct KiwiVisionLensHelpTests {
    private static func squashed() throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                        + "KiwiVisionLensOverrides.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    /// Dim has no `?` on the Default page, so it has none here; every
    /// other row hands the chrome the Default row's own string.
    @Test("every row with a Default `?` hands it to the chrome")
    func rowsCarryTheirHelp() throws {
        let source = try Self.squashed()
        for help in [
            "help:KiwiVisionLevelsCard.blurHelp",
            "help:KiwiVisionLevelsCard.fadeDurationHelp,subject:label",
            "help:KiwiVisionLevelsCard.fadeCurveHelp,subject:label",
            "help:KiwiVisionClearCard.appHelp",
            "help:KiwiVisionClearCard.wallpaperHelp",
            "help:KiwiVisionMaximizeRow.help,subject:label",
            "help:KiwiVisionAppearanceCard.help,subject:label",
        ] {
            #expect(source.occurrences(of: help) == 1, "\(help)")
        }
        // The toggle rows' one chrome takes the help it is handed.
        #expect(
            source.contains(
                "inherited:(label,Self.onOff(global)),help:help,"
                    + "subject:label"
            )
        )
        // Every chrome but dim's, which has no Default `?`, takes a
        // help: a further row's chrome without one reds here.
        let chromes = source.components(separatedBy: "OverrideChrome(")
            .dropFirst()
            .map { $0.components(separatedBy: "){").first ?? "" }
        #expect(chromes.count > 1)
        for args in chromes where !args.contains("Self.percent(") {
            #expect(args.contains("help:"), "\(args)")
        }
    }

    @Test("the follows caption heads the form, on no one card")
    func captionHeadsTheForm() throws {
        let source = try Self.squashed()
        let caption = try #require(
            source.range(of: "Text(KiwiVisionLensWords.followsCaption)")
        )
        let first = try #require(source.range(of: "SettingsSection("))
        #expect(caption.upperBound <= first.lowerBound)
        #expect(!source.contains("caption:KiwiVisionLensWords"))
    }
}
