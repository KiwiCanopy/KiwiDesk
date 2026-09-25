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
        #expect(SpaceAddName.resolve("  ", among: spaces) == .add(4))
        #expect(SpaceAddName.resolve("", among: []) == .add(1))
    }

    @Test("a taken number is suffixed until free")
    func takenNumberIsSuffixed() {
        #expect(
            SpaceAddName.nextNumber(among: [SpaceID(1), SpaceID(3)])
                == SpaceID("3 (1)")
        )
        #expect(
            SpaceAddName.nextNumber(
                among: [SpaceID(3), SpaceID("3 (1)")]
            ) == SpaceID("3 (2)")
        )
    }

    @Test("a typed name is kept trimmed, a taken one refused")
    func typedNames() {
        #expect(
            SpaceAddName.resolve(" Mail ", among: spaces)
                == .add(SpaceID("Mail"))
        )
        #expect(
            SpaceAddName.resolve("Work", among: spaces)
                == .refused(.taken("Work"))
        )
        // The refusal names the Space as it is, not as typed.
        #expect(
            SpaceAddName.resolve("03", among: spaces)
                == .refused(.taken("3"))
        )
    }

    private func rowSource() throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/SpaceAddRow.swift"
            )
        return try SourceScan.strippedSource(at: file)
    }

    @Test("+ adds what the rule resolves, greyed only on a refusal")
    func buttonWiresTheRule() throws {
        let source = try rowSource()
        #expect(source.contains(".disabled(resolved.space == nil)"))
        let add = try #require(
            SourceScan.declarationBody(
                after: "private func add()",
                in: source
            )
        )
        #expect(add.contains("guard let space = resolved.space"))
        #expect(add.contains("onAdd(space)"))
    }

    @Test("Return adds only a typed name and speaks a refusal")
    func returnWiresTheRule() throws {
        let source = try rowSource()
        #expect(source.contains(".onSubmit(submit)"))
        let submit = try #require(
            SourceScan.declarationBody(
                after: "private func submit()",
                in: source
            )
        )
        #expect(submit.contains("guard !typed.trimmed.isEmpty"))
        #expect(submit.contains("announce(notice.sentence)"))
    }

    @Test("the row draws the rule's refusal")
    func rowDrawsTheRefusal() throws {
        let caption = SourceScan.declarationBody(
            after: "if let notice = resolved.notice",
            in: try rowSource()
        )
        #expect(caption?.contains("SpaceNameNoticeCaption(") == true)
    }
}
