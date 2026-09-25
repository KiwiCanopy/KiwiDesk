import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The add row makes a Space without a name (#1531): an empty
/// field takes the next number, a taken name is refused and said.
@Suite("Space add row naming (#1531)")
struct SpaceAddNameTests {
    private let spaces = [SpaceID(1), SpaceID("Work"), SpaceID(3)]

    @Test("an empty field takes the count plus one")
    func emptyTakesNextNumber() {
        #expect(SpaceAddName.resolve("  ", among: spaces) == SpaceID(4))
        #expect(SpaceAddName.resolve("", among: []) == SpaceID(1))
    }

    @Test("a taken number is suffixed until free")
    func takenNumberIsSuffixed() {
        let full = [SpaceID(1), SpaceID(3)]
        #expect(SpaceAddName.nextNumber(among: full) == SpaceID("3 (1)"))
        let fuller = full + [SpaceID("3 (1)")]
        #expect(
            SpaceAddName.nextNumber(among: fuller) == SpaceID("4")
        )
        let fullest = [SpaceID(2), SpaceID(3), SpaceID("3 (1)")]
        #expect(
            SpaceAddName.nextNumber(among: fullest)
                == SpaceID("4")
        )
    }

    @Test("a typed name is kept trimmed, a taken one refused")
    func typedNames() {
        #expect(
            SpaceAddName.resolve(" Mail ", among: spaces)
                == SpaceID("Mail")
        )
        #expect(SpaceAddName.resolve("Work", among: spaces) == nil)
        #expect(SpaceAddName.resolve("3", among: spaces) == nil)
    }

    @Test("the row adds what the rule resolves and says a refusal")
    func rowWiresTheRule() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/SpacesSection.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        let add = try #require(
            SourceScan.declarationBody(
                after: "private func addSpace()",
                in: source
            )
        )
        #expect(add.contains("guard let space = addTarget"))
        let target = try #require(
            SourceScan.declarationBody(
                after: "private var addTarget: SpaceID?",
                in: source
            )
        )
        #expect(target.contains("SpaceAddName.resolve("))
        let refused = SourceScan.declarationBody(
            after: "if addTarget == nil",
            in: source
        )
        #expect(refused?.contains("SpaceNameNoticeCaption(") == true)
    }
}
