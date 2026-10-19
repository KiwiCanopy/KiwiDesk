import Foundation
import Testing

/// The header's back chip sheds its word with the chrome and never
/// wraps it where it stays: squeezed by a narrow row, "Home" stacked
/// a letter per line under the chevron.
///
/// Off the main actor: a pure source read.
@Suite("Settings back chip")
struct SettingsBackChipTests {
    @Test("the back chip sheds its word below the chrome breakpoint")
    func backChipShedsItsWord() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsHeaderBar.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "private var backChip:",
                in: text
            )
        )
        let squashed = body.split(whereSeparator: \.isWhitespace)
            .joined()
        let word = "Text(L(\"home.back\",\"Home\"))"
        #expect(squashed.occurrences(of: word) == 1)
        #expect(
            squashed.contains(
                "if!width.collapsesChrome{" + word
                    + ".font(.callout).fixedSize()}"
            )
        )
        // VoiceOver keeps the name the word gave.
        #expect(
            squashed.contains(".accessibilityLabel(L(\"home.back\"")
        )
    }
}
