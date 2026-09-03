import Foundation
import Testing

@testable import KiwiDesk

/// A DEAD row says so in the flow (#1126): the chord outlined in
/// `danger`, a worded caption in the recorder's caption slot, the
/// badge in `danger`, and the record button's VoiceOver value
/// carrying the cost. Wires pinned at their use sites — the
/// `KeyboardConflictWiringTests` shape — contiguous through the
/// gate AND the stroke, so a branch that keeps its condition and
/// stops drawing reds too. Off the main actor; three file reads.
@Suite("Conflict row treatment (#1126)")
struct ConflictRowTreatmentTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent(
            "Sources/KiwiDesk/Settings/Components/Keybindings"
        )

    private static let needles: [String: [String]] = [
        "Recorder/KeyRecorderChrome.swift": [
            // The dead outline is drawn on the REST shape only,
            // in `danger`, gated on the flag.
            "}elseifdead{RoundedRectangle(cornerRadius:5)"
                + ".strokeBorder(SettingsTheme.danger,"
        ],
        "Recorder/KeyRecorderField+Conflict.swift": [
            // The caption exists only for a dead row and speaks
            // the same sentence the badge carries.
            "ifisDead,letconflict{HStack(spacing:4){"
                + "Image(systemName:\"exclamationmark.triangle.fill\")"
                + "Text(conflict)}.font(.caption)"
                + ".foregroundStyle(SettingsTheme.danger)",
            // The badge reads the same flag.
            "isDead?SettingsTheme.danger:SettingsTheme.warningInk",
        ],
        "Recorder/KeyRecorderField.swift": [
            // The chrome is handed the flag…
            "RecorderButtonChrome(recording:recording,dead:isDead)",
            // …the caption is mounted under the field…
            "clearButton}deadCaption",
            // …and a named control is valued with its cost (#812).
            ".accessibilityValue(isDead&&conflict!=nil?L(",
        ],
        // Every recorder mount hands the severity down — a row
        // that passes only the tooltip renders the old chrome.
        "KeybindingNavRow.swift": ["severity:severity,"],
        "KeybindingAppGroup+Row.swift": [
            "severity:ConflictText.severity("
        ],
    ]

    @Test("the dead-row wires survive in their bodies")
    func wiresAreDrawn() throws {
        for (file, wants) in Self.needles {
            let url = Self.root.appendingPathComponent(file)
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            #expect(!wants.isEmpty)
            for want in wants {
                #expect(
                    source.contains(want),
                    Comment(
                        rawValue: "\(file) lost its dead-row wire: "
                            + want
                    )
                )
            }
        }
    }

    /// The Lua drawer's recorder is the third mount, in another
    /// directory.
    @Test("the Lua drawer's recorder hands the severity down")
    func luaDrawerPassesSeverity() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Lua/"
                    + "AdvancedLuaGroup.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
        #expect(source.contains("severity:ConflictText.severity("))
    }
}
