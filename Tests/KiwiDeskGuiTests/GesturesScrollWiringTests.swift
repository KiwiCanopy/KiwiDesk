import Foundation
import Testing

@testable import KiwiDesk

/// Mouse & trackpad ▸ Scroll gestures (#1656): the group leads the
/// drawer, the recorder's refusal is Core's, the travel field
/// greys while the box is off, and every value row carries its
/// "Applies to" column.
@Suite("Scroll gestures group wiring (#1656)")
struct GesturesScrollWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let dir = "Sources/KiwiDesk/Settings/Components/Gestures/"

    private static func squash(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    private static func source(_ file: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(dir + file),
                encoding: .utf8
            )
        )
    }

    @Test("the scroll group is the drawer's first")
    func scrollGroupLeads() throws {
        let drawer = try Self.source("GesturesDrawer.swift")
        let scroll = try #require(
            drawer.range(of: "GesturesScrollEntries(model:")
        )
        let windows = try #require(
            drawer.range(of: "\"shortcuts.gestures.group.windows\"")
        )
        let heading = try #require(
            drawer.range(of: "\"shortcuts.gestures.group.scroll\"")
        )
        #expect(heading.lowerBound < scroll.lowerBound)
        #expect(scroll.lowerBound < windows.lowerBound)
    }

    @Test("a recorded chord is judged by Core's refusal before it lands")
    func recorderAsksCore() throws {
        let field = Self.squash(
            try Self.source("ScrollChordRecorderField.swift")
        )
        let refusal = try #require(
            field.range(of: "ScrollChordRefusal.of(recorded,")
        )
        let write = try #require(field.range(of: "chord=recorded"))
        #expect(refusal.lowerBound < write.lowerBound)
        // The refused branch leaves before the write, not only
        // ahead of it in the text.
        let branch = try #require(
            SourceScan.declarationBody(
                after: "if let found = ScrollChordRefusal.of(",
                in: try Self.source("ScrollChordRecorderField.swift")
            )
        )
        #expect(branch.contains("return"))
        #expect(field.contains("mode:.modifiers"))
    }

    @Test("the travel field greys, never hides, while the box is off")
    func travelGreys() throws {
        let group = try Self.source("GesturesScrollEntries.swift")
        let row = try #require(
            SourceScan.declarationBody(
                after: "private var travelRow",
                in: group
            )
        )
        #expect(row.contains("StepperRow("))
        #expect(row.contains(".disabled(!gestures.longSwipes)"))
        // Hidden by any spelling: no `if` reads the box.
        let hides = try NSRegularExpression(
            pattern: "\\bif\\b[^\\n{]*longSwipes"
        )
        #expect(
            hides.numberOfMatches(
                in: group,
                range: NSRange(group.startIndex..., in: group)
            ) == 0
        )
    }

    @Test("every value row carries its Applies to column")
    func everyRowReaches() throws {
        let group = try Self.source("GesturesScrollEntries.swift")
        for field in [
            "reachRow(.pan)", "reachRow(.longSwipes)",
            "reachRow(.stepDistance)",
        ] {
            #expect(group.contains(field), "\(field) has no column")
        }
        // Both Natural rows, through the one row builder that
        // itself carries the column.
        // One row per input, each keyed by its own field.
        let squashed = Self.squash(group)
        #expect(squashed.contains("naturalRow(.naturalTrackpad,"))
        #expect(squashed.contains("naturalRow(.naturalMouse,"))
        let natural = try #require(
            SourceScan.declarationBody(
                after: "private func naturalRow(",
                in: group
            )
        )
        #expect(natural.contains("reachRow(field)"))
        #expect(group.contains("family: .scroll"))
    }
}
