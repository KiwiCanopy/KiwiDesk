import Foundation
import Testing

/// A button opening a pop-up of its own reads as the native pop-up
/// beside it (owner ruling 2026-10-17): one seal pairing a capsule
/// face with no edge to the neutral label, taken by each trigger,
/// whose label hugs its name — no spacer stretching it across the
/// column. And the dropdowns those triggers open share one cursor
/// corner and keep a long family name apart by its ends. Shapes,
/// never values (tests.md ▸ #1021).
@Suite("Pop-up triggers")
struct PopUpTriggerTests {
    private static let settings = "Sources/KiwiDesk/Settings/"

    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(settings + path)
        )
    }

    private static func body(
        _ opener: String,
        in path: String
    ) throws -> String {
        try #require(
            SourceScan.declarationBody(after: opener, in: source(path)),
            "\(opener) is gone from \(path)"
        )
    }

    @Test("the seal pairs the pop-up face with the neutral label")
    func sealPairs() throws {
        let seal = try Self.source("SettingsActionButton.swift")
        #expect(
            SourceScan.adjacentPairs(
                in: seal,
                line: "buttonStyle(PopUpTriggerStyle())",
                followedBy: ".neutralButtonLabel()"
            ) == 1
        )
    }

    @Test("the pop-up face is a capsule with no edge")
    func capsuleWithoutEdge() throws {
        let face = try Self.source("PopUpTriggerStyle.swift")
        #expect(face.contains("Capsule().fill("))
        #expect(
            face.contains(
                ".contentShape([.interaction, .focusEffect], Capsule())"
            )
        )
        #expect(!face.contains("strokeBorder"))
        #expect(!face.contains("stroke("))
        #expect(!face.contains("RoundedRectangle"))
        let squashed = face.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(
            squashed.contains("pressed:isEnabled&&configuration.isPressed")
        )
        // It lifts under the pointer, gated like the action chip.
        #expect(squashed.contains("hovered:isEnabled&&hovered"))
        #expect(squashed.contains(".onHover{hovered=$0}"))
    }

    /// Each trigger takes the seal and no action-button face, and
    /// its label carries no spacer, which made it greedy.
    @Test("both triggers take the seal and hug their name")
    func triggersHug() throws {
        let font = "Components/Bars/KiwiShelfCard+Font.swift"
        let picker = "Components/Common/AppPickerButton.swift"
        let trigger = try Self.body("private var trigger", in: font)
        #expect(trigger.occurrences(of: ".settingsPopUpTrigger()") == 1)
        #expect(!trigger.contains("settingsActionButton"))
        for path in [font, picker] {
            let label = try Self.body("} label: {", in: path)
            #expect(!label.contains("Spacer("), "\(path)'s trigger is greedy")
            #expect(label.contains(".lineLimit(1)"))
        }
        let button = try Self.source(picker)
        #expect(button.occurrences(of: ".settingsPopUpTrigger()") == 1)
        #expect(!button.contains("settingsActionButton"))
    }

    @Test("a long family name truncates in the middle")
    func familyNameMiddle() throws {
        let name = try Self.body(
            "private struct FamilyName",
            in: "Components/Bars/FontFamilyPicker.swift"
        )
        #expect(name.contains(".truncationMode(.middle)"))
    }

    /// One corner for every cursor: the modifier takes no radius
    /// and draws the style's one constant.
    @Test("the cursor's corner has one home")
    func oneRadius() throws {
        let path = "Components/Common/DropdownCursor.swift"
        let text = try Self.source(path)
        let signature = try #require(
            SourceScan.callArguments(of: "func dropdownCursorRow(", in: text)
        )
        #expect(!signature.contains("cornerRadius"))
        let row = try Self.body("func dropdownCursorRow(", in: path)
        #expect(
            row.contains(
                "RoundedRectangle(cornerRadius: DropdownRowStyle.cornerRadius)"
            )
        )
    }
}
