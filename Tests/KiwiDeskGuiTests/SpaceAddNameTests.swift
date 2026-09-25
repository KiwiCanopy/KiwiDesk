import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The add row makes a Space without a name (#1531): an empty
/// field takes the next number, a taken name is refused and said.
@Suite("Space add row naming (#1531)")
struct SpaceAddNameTests {
    private let spaces = [SpaceID(1), SpaceID("Work"), SpaceID(3)]

    @Test("an empty field takes the smallest free number")
    func emptyTakesSmallestFree() {
        #expect(SpaceAddName.resolve("  ", among: spaces) == .add(2))
        #expect(SpaceAddName.resolve("", among: []) == .add(1))
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

    private func sectionSource() throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/SpacesSection.swift"
            )
        return try SourceScan.strippedSource(at: file)
    }

    @Test("+ adds what the rule resolves, greyed only on a refusal")
    func buttonWiresTheRule() throws {
        let source = try rowSource()
        let button = try #require(
            source.range(of: "Button(action: add)")
                .map { String(source[$0.lowerBound...]) }
        )
        let untilHelp = try #require(
            button.range(of: ".help(").map {
                String(button[..<$0.lowerBound])
            }
        )
        #expect(untilHelp.contains(".disabled(resolved.space == nil)"))
        let add = try #require(
            SourceScan.declarationBody(
                after: "private func add()",
                in: source
            )
        )
        #expect(add.contains("guard let space = resolved.space"))
        #expect(add.contains("onAdd(space)"))
    }

    @Test("Return adds a typed name, speaks a refusal, never stale")
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
        #expect(submit.contains("DelayedAnnouncement.schedule("))
        #expect(submit.contains("add()"))
        let edited = SourceScan.declarationBody(
            after: ".onChange(of: typed)",
            in: source
        )
        #expect(edited?.contains("announcement?.cancel()") == true)
        let gone = SourceScan.declarationBody(
            after: ".onDisappear",
            in: source
        )
        #expect(gone?.contains("announcement?.cancel()") == true)
    }

    @Test("the section appends what the row adds")
    func sectionWiresTheRow() throws {
        let source = try sectionSource()
        let row = SourceScan.declarationBody(
            after: "SpaceAddRow(spaces: model.config.spaces)",
            in: source
        )
        #expect(row?.contains("model.config.spaces.append($0)") == true)
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
