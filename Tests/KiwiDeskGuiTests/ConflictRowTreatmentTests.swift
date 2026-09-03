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
            // in `danger`, gated on the flag. The geometry in
            // this needle is GLUE holding it contiguous through
            // the gate AND the stroke (tests.md ▸ a drawn
            // VALUE) — not an assertion about the radius, and
            // `lineWidth` is deliberately outside it.
            "}elseifdead{RoundedRectangle(cornerRadius:5)"
                + ".strokeBorder(SettingsTheme.danger,"
        ],
        "Recorder/KeyRecorderField+Conflict.swift": [
            // The caption exists only for a dead row and speaks
            // the same sentence the badge carries. Spacing and
            // font are glue, as above.
            "ifisDead,letsentence=conflictSentence{"
                + "HStack(spacing:4){"
                + "Image(systemName:\"exclamationmark.triangle.fill\")"
                + "Text(sentence)}.font(.caption)"
                + ".foregroundStyle(SettingsTheme.danger)",
            // The badge reads the same flag.
            "isDead?SettingsTheme.danger:SettingsTheme.warningInk",
        ],
        "Recorder/KeyRecorderField.swift": [
            // The chrome is handed the flag…
            "RecorderButtonChrome(recording:recording,dead:isDead)",
            // …the caption is mounted under the field…
            "clearButton}deadCaption",
            // …a dead row never also claims "Active now"…
            "ifletliveFeedback,showsFeedback(liveFeedback){",
            // …and the tier and its sentence arrive as ONE
            // value, declared `let` with no default so the
            // memberwise init REQUIRES it: widening this to a
            // defaulted `var` is what would let a new mount
            // render the old chrome unseen.
            "letreading:ConflictReading?",
        ],
        // Every recorder mount mints that one value, and the
        // needle runs THROUGH the live set it is minted from:
        // stopping at the open paren left a mount free to pass
        // `disabled: []`, which reads every dormant chord as
        // dead (guard-prover, 2026-09-03).
        "KeybindingNavRow.swift": [
            "returnConflictText.reading(for:bindings[index],"
                + "in:bindings,config:model.config,"
                + "disabled:disabledSystemShortcuts)"
        ],
        "KeybindingAppGroup+Row.swift": [
            "reading:ConflictText.reading(for:binding.wrappedValue,"
                + "in:bindings,config:model.config,"
                + "disabled:disabledSystemShortcuts)"
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
        #expect(
            source.contains(
                "reading:ConflictText.reading(for:binding.wrappedValue,"
                    + "in:bindings,config:model.config,"
                    + "disabled:disabledSystemShortcuts)"
            )
        )
    }
}
