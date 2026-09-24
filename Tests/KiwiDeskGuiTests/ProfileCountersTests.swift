import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The screen and Space counters leading a profile row and a
/// preset card (#1624): the counts are symbols, so their sentence
/// must reach the pointer as the tooltip and VoiceOver as the
/// name's value, on both surfaces. Locale pinned per body (#740);
/// the scan clauses read four files once each.
@MainActor
@Suite("Profile counters (#1624)")
struct ProfileCountersTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private static let settings = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk/Settings")

    private func squashed(_ path: String) throws -> String {
        let raw = try String(
            contentsOf: Self.settings.appendingPathComponent(path),
            encoding: .utf8
        )
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    @Test("the sentence names screens and Spaces, overrides third")
    func sentence() {
        pinEnglish()
        #expect(
            ProfileCounters.sentence(screens: 1, spaces: 4)
                == "1 screen · 4 Spaces"
        )
        #expect(
            ProfileCounters.sentence(screens: 2, spaces: 1, overrides: 0)
                == "2 screens · 1 Space"
        )
        #expect(
            ProfileCounters.sentence(screens: 1, spaces: 4, overrides: 2)
                == "1 screen · 4 Spaces · 2 shortcut overrides"
        )
        #expect(
            ProfileCounters.sentence(screens: 1, spaces: 3, overrides: 1)
                == "1 screen · 3 Spaces · 1 shortcut override"
        )
    }

    /// The symbols say nothing to VoiceOver, so the counters hide
    /// and the tooltip carries their own sentence.
    @Test("the counters show their sentence and hide from VoiceOver")
    func countersCarryTheSentence() throws {
        let source = try squashed(
            "Components/Profiles/ProfileCounters.swift"
        )
        #expect(source.contains(".help(sentence)"))
        #expect(source.contains(".accessibilityHidden(true)"))
    }

    /// Every surface that draws the counters hands VoiceOver their
    /// sentence, found by construction site rather than a list of
    /// files, so a third surface cannot go symbol-only.
    @Test("every surface drawing the counters reads their sentence")
    func everySurfaceReadsTheSentence() throws {
        let value = try Regex(
            #"\.accessibilityValue\([A-Za-z]+(\([A-Za-z]+\))?\.sentence\)"#
        )
        var surfaces = 0
        for file in try SourceScan.swiftSources(under: Self.settings)
        where file.lastPathComponent != "ProfileCounters.swift" {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace).joined()
            guard source.contains("ProfileCounters(") else { continue }
            surfaces += 1
            #expect(
                source.contains(value),
                Comment(rawValue: file.lastPathComponent)
            )
        }
        #expect(surfaces >= 2)
    }

    /// The value sits on the NAME, read right after it, and the
    /// row no longer draws the sentence as a caption.
    @Test("the profile row reads the sentence after the name")
    func profileRowWiring() throws {
        let row = try squashed("Sections/ProfilesSection.swift")
        #expect(
            row.contains(
                "ProfileCounters(screens:summary.count,"
                    + "spaces:summary.spaceCount,"
                    + "overrides:summary.shortcutOverrideCount)"
            )
        )
        let name = try #require(row.range(of: "Text(summary.name)"))
        let rename = try #require(
            row.range(of: "renameButton(summary.name)")
        )
        #expect(name.upperBound < rename.lowerBound)
        #expect(
            row[name.upperBound..<rename.lowerBound].contains(
                ".accessibilityValue(counters(summary).sentence)"
            )
        )
        // The sentence's one use is the name's value; any other
        // spelling of a caption is a second use (guard-prover).
        #expect(row.occurrences(of: "counters(summary).sentence") == 1)
        #expect(!row.contains("ProfileCounters.sentence"))
    }

    @Test("the preset card reads the sentence after its title")
    func presetCardWiring() throws {
        let card = try squashed("Components/Profiles/PresetCard.swift")
        #expect(
            card.contains(
                "ProfileCounters(screens:layout.screenCount,"
                    + "spaces:layout.spaceCount)"
            )
        )
        let title = try #require(
            card.range(of: "Text(layout.displayName)")
        )
        let badge = try #require(card.range(of: "iflayout.isStandard"))
        #expect(title.upperBound < badge.lowerBound)
        #expect(
            card[title.upperBound..<badge.lowerBound].contains(
                ".accessibilityValue(counters.sentence)"
            )
        )
        #expect(card.occurrences(of: "counters.sentence") == 1)
        #expect(!card.contains("ProfileCounters.sentence"))
    }

    /// `display` beside a number is the row's screen count; the
    /// collapsed setups chip counting SETUPS says so in words.
    @Test("the collapsed setups chip draws no display glyph")
    func collapsedChipIsText() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: Self.settings.appendingPathComponent(
                    "Sections/ProfilesSection+ScreenSetups.swift"
                ),
                encoding: .utf8
            )
        )
        let text = Array(source)
        let needle = Array("func collapsedSetups")
        let start = try #require(
            (0...(text.count - needle.count)).first {
                Array(text[$0..<($0 + needle.count)]) == needle
            }
        )
        // The body opens at the first brace past the signature.
        var cursor = try #require(
            text[start...].firstIndex(of: "{")
        )
        let body = try #require(
            SourceScan.balanced(
                text,
                from: &cursor,
                open: "{",
                close: "}"
            )
        )
        #expect(body.contains("\"profiles.sets.collapsed\""))
        #expect(!body.contains("\"display\""))
    }
}
