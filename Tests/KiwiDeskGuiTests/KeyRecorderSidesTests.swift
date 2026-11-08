import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Sides pull-down (#2614): its words and order, and the
/// wiring no behaviour suite reaches — the slot in the field's row
/// and footprint, gated on the switch and on rest, and a pick that
/// commits through the recorder's preflight.
@Suite("Recorder Sides pull-down (#2614)")
@MainActor
struct KeyRecorderSidesTests {
    private static let recorder = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent(
            "Sources/KiwiDesk/Settings/Components/Keybindings/Recorder"
        )

    private static func source(_ name: String) throws -> String {
        try SourceScan.strippedSource(
            at: recorder.appendingPathComponent(name)
        )
    }

    @Test("choices run Left, Right, Either side under a titled section")
    func choices() {
        LocalizationManager.shared.select("en")
        #expect(KeyRecorderField.choices == [.left, .right, nil])
        #expect(KeyRecorderField.choiceText(.left) == "Left")
        #expect(KeyRecorderField.choiceText(.right) == "Right")
        #expect(KeyRecorderField.choiceText(nil) == "Either side")
        #expect(KeyRecorderField.sectionTitle(.command) == "⌘ Command")
    }

    @Test("the slot sits before the well, gated on sides and rest")
    func slotWiring() throws {
        let field = try Self.source("KeyRecorderField.swift")
        let badge = try #require(field.range(of: "conflictBadge\n"))
        let slot = try #require(field.range(of: "sidesSlot\n"))
        let well = try #require(field.range(of: "recordButton\n"))
        #expect(badge.upperBound <= slot.lowerBound)
        #expect(slot.upperBound <= well.lowerBound)
        let sides = try Self.source("KeyRecorderField+Sides.swift")
        #expect(sides.contains("if let sides = recorderSides {"))
        #expect(sides.contains("recording: recording,"))
        #expect(sides.contains("hyperKey: sides.hyperKey"))
        // The footprint holds the slot under the same switch.
        let footprint = try Self.source("KeyRecorderField+Footprint.swift")
        #expect(footprint.contains("if recorderSides != nil { slot }"))
    }

    @Test("a pick commits through the preflight, and names itself")
    func pickWiring() throws {
        let sides = try Self.source("KeyRecorderField+Sides.swift")
        #expect(
            sides.contains(
                "if let text = Self.pickedText(side, of: kind, in: parsed, "
                    + "hyperKey) {\n            commit(text)\n        }"
            )
        )
        #expect(!sides.contains("onRecord("))
        #expect(
            sides.contains(
                #"systemImage: "arrow.left.and.right")"#
            )
        )
        #expect(!sides.contains("Image(systemName:"))
    }

    @Test("the menu shows at rest only, for a modifier that takes a side")
    func menuShows() {
        let menu = { (combo: String, recording: Bool) in
            KeyRecorderField.sidesMenuCombo(
                combo,
                recording: recording,
                hyperKey: nil
            )
        }
        #expect(menu("rcmd+h", false) == KeyCombo.parse("rcmd+h"))
        #expect(menu("rcmd+h", true) == nil)
        #expect(menu("h", false) == nil)
        #expect(menu("hyper+cmd+h", false) == nil)
        #expect(menu("", false) == nil)
        #expect(
            KeyRecorderField.sidesMenuCombo(
                "cmd+h",
                recording: false,
                hyperKey: .rightCommand
            ) == nil
        )
    }

    @Test("a pick stores the new chord, and nothing for the row's own")
    func pickedText() throws {
        let stored = try #require(KeyCombo.parse("cmd+h"))
        let pick = { (side: ModifierSide?) in
            KeyRecorderField.pickedText(side, of: .command, in: stored, nil)
        }
        #expect(pick(nil) == nil)
        #expect(pick(.right) == "rcmd+h")
        #expect(pick(.left) == "lcmd+h")
    }
}
