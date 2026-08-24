import Foundation
import Testing

@testable import KiwiDesk

/// The two links between `Profile.openingModes()` and the glyph
/// a saved profile's row actually draws (#789, #959).
///
/// `ProfileOpeningModesTests` holds what the accessor answers and
/// `ProfileScreenPipsTests` holds what the picture draws from
/// what it is handed — but the accessor has exactly ONE
/// production consumer, and nothing between them was pinned. So
/// #959's visible symptom (a blank outline beside a caption
/// announcing six Spaces) could come back through a summary that
/// stopped asking, or a row that stopped passing, with every one
/// of those tests green (guard-prover, 2026-08-24).
///
/// A scan rather than a render: both links are one argument at
/// one call site, and what can break them is someone dropping
/// the argument or handing over a constant.
@Suite("Profile screen pips wiring")
struct ProfileScreenPipsWiringTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    private func squashed(_ path: String) throws -> String {
        let url = Self.root
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    @Test("the summary asks the profile what its screens open in")
    func summaryReadsTheAccessor() throws {
        #expect(
            try squashed("SettingsModel+Refresh.swift").contains(
                "openingModes:profile.openingModes()"
            ),
            Comment(
                rawValue:
                    "the profile summary no longer derives its "
                    + "screen modes from the profile — every "
                    + "row's pips go bare while both the "
                    + "accessor's and the picture's own suites "
                    + "stay green (#959)"
            )
        )
    }

    @Test("the row hands the summary's answer to the picture")
    func rowPassesTheAnswerThrough() throws {
        #expect(
            try squashed("Sections/ProfilesSection.swift")
                .contains("openingModes:summary.openingModes"),
            Comment(
                rawValue:
                    "the saved-profile row stopped passing its "
                    + "opening modes to ProfileScreenPips — the "
                    + "picture defaults to [] and draws bare "
                    + "outlines (#789)"
            )
        )
    }
}
