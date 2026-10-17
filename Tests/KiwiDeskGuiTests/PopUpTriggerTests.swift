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

    /// The pop-up face is the shared chip face's capsule arm, which
    /// draws no edge; the press and hover gates live there once and
    /// are `ButtonChipStyleTests`'.
    @Test("the pop-up face is a capsule with no edge")
    func capsuleWithoutEdge() throws {
        let style = try Self.source("PopUpTriggerStyle.swift")
        #expect(
            style.contains(
                "ChipFace(configuration: configuration, popUp: true)"
            )
        )
        #expect(!style.contains("stroke"))
        let face = try Self.source("ChipFace.swift")
        let squashed = face.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(squashed.contains("popUp?AnyShape(Capsule())"))
        // The one edge sits under exactly `if !popUp`.
        #expect(squashed.contains("if!popUp{bezel.strokeBorder("))
        #expect(face.occurrences(of: "strokeBorder(") == 1)
        #expect(face.occurrences(of: "stroke(") == 0)
    }

    /// The style is spelled once in the tree, in the seal, so no
    /// trigger takes the face without the neutral label.
    @Test("the pop-up style is reached only through its seal")
    func styleOnlyInSeal() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var sites: [String: Int] = [:]
        for url in try SourceScan.swiftSources(under: root) {
            let count = try SourceScan.strippedSource(at: url)
                .occurrences(of: "PopUpTriggerStyle()")
            if count > 0 { sites[url.lastPathComponent] = count }
        }
        #expect(sites == ["SettingsActionButton.swift": 1])
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
            // The floor bounds the whole trigger, name and chevron,
            // never the name alone.
            let squashed = label.split(whereSeparator: \.isWhitespace)
                .joined()
            #expect(squashed.occurrences(of: ".frame(minWidth:") == 1)
            #expect(squashed.contains(")}.frame(minWidth:"))
        }
        // A tall face keeps the system line box.
        let fontLabel = try Self.body("} label: {", in: font)
        #expect(fontLabel.contains(".frame(height: Self.systemLineHeight)"))
        #expect(fontLabel.contains(".clipped()"))
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
