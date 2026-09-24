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
    /// and the tooltip carries the sentence it was handed.
    @Test("the counters show their sentence and hide from VoiceOver")
    func countersCarryTheSentence() throws {
        let source = try squashed(
            "Components/Profiles/ProfileCounters.swift"
        )
        #expect(source.contains(".help(help)"))
        #expect(source.contains(".accessibilityHidden(true)"))
    }

    /// Each surface hands the counters the sentence of its OWN
    /// counts and reads the same sentence after the name.
    @Test("the profile row wires the sentence to both channels")
    func profileRowWiring() throws {
        let row = try squashed("Sections/ProfilesSection.swift")
        #expect(
            row.contains(
                "ProfileCounters(screens:summary.count,"
                    + "spaces:summary.spaceCount,"
                    + "help:subtitle(summary))"
            )
        )
        #expect(row.contains(".accessibilityValue(subtitle(summary))"))
        // The caption line moved into the tooltip.
        #expect(!row.contains("Text(subtitle("))
        let subtitle = try squashed(
            "Sections/ProfilesSection+Subtitle.swift"
        )
        #expect(
            subtitle.contains(
                "overrides:summary.shortcutOverrideCount"
            )
        )
    }

    @Test("the preset card wires the sentence to both channels")
    func presetCardWiring() throws {
        let card = try squashed("Components/Profiles/PresetCard.swift")
        #expect(
            card.contains(
                "ProfileCounters(screens:layout.screenCount,"
                    + "spaces:layout.spaceCount,help:countsSentence)"
            )
        )
        #expect(card.contains(".accessibilityValue(countsSentence)"))
        #expect(
            card.contains(
                "ProfileCounters.sentence(screens:layout.screenCount,"
                    + "spaces:layout.spaceCount)"
            )
        )
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
