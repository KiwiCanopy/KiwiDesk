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
        #expect(sides.contains("if !recording,"))
        #expect(sides.contains("hyperKey: sides.hyperKey"))
        // The footprint holds the slot under the same switch.
        let footprint = try Self.source("KeyRecorderField+Footprint.swift")
        #expect(footprint.contains("if recorderSides != nil { slot }"))
    }

    @Test("a pick commits through the preflight, and names itself")
    func pickWiring() throws {
        let sides = try Self.source("KeyRecorderField+Sides.swift")
        #expect(sides.contains("commit(text)"))
        #expect(!sides.contains("onRecord("))
        #expect(sides.contains("picked != parsed"))
        #expect(
            sides.contains(
                #"systemImage: "arrow.left.and.right")"#
            )
        )
        #expect(!sides.contains("Image(systemName:"))
    }
}
