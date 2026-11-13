import Foundation
import Testing

@testable import KiwiDesk

/// Mouse & trackpad ▸ Scroll gestures (#1656, #1519): the group
/// leads the drawer, the travel field greys while the box is off,
/// and every value row carries its "Applies to" column. The chord
/// recorders left with #3199; #3183's list card replaces them.
@Suite("Scroll gestures group wiring (#1656, #1519)")
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

    /// The scroll gestures open the Holding a modifier card (#3184).
    @Test("the scroll entries lead the Holding a modifier card")
    func scrollGroupLeads() throws {
        let part = Self.squash(try Self.source("GesturesPart.swift"))
        #expect(
            part.contains(
                "SettingsSection(SettingsCatalog.shortcuts.gesturesModifier)"
                    + "{GesturesScrollEntries(model:model)"
            )
        )
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
            "reachRow(.longSwipes)", "reachRow(.stepDistance)",
        ] {
            #expect(group.contains(field), "\(field) has no column")
        }
        #expect(group.contains("family: .scroll"))
        // Both Natural rows lead their device's card (#3183), each
        // naming its own input's field, through the one row that
        // carries the column.
        let card = try Self.source("GestureListCard.swift")
        #expect(
            Self.squash(card).contains(
                "device==.mouse?.naturalMouse:.naturalTrackpad"
            )
        )
        let natural = try #require(
            SourceScan.declarationBody(
                after: "private var naturalRow:",
                in: card
            )
        )
        #expect(natural.contains("naturalReach"))
        let body = try #require(
            SourceScan.declarationBody(after: "var body:", in: card)
        )
        #expect(body.contains("naturalRow"))
        let reach = try #require(
            SourceScan.declarationBody(
                after: "private var naturalReach:",
                in: card
            )
        )
        #expect(reach.contains("model.scrollReach(field.rawValue)"))
        #expect(reach.contains("family: .scroll"))
    }

    /// Each group is a card of its own (#3184): entries inside a
    /// card are split by a `GestureRule`, a card's edge needs none,
    /// and no in-card heading is left from the one-card shape.
    @Test("each group is its own card, its entries ruled apart")
    func groupsAreCards() throws {
        let part = Self.squash(try Self.source("GesturesPart.swift"))
        #expect(!part.contains("SettingsGroupHeading("))
        #expect(!part.contains("GestureRule()}SettingsSection("))
        // No card ends on a rule, the last one included.
        #expect(!part.contains("GestureRule()}"))
        #expect(
            part.components(separatedBy: "SettingsSection(").count - 1
                == GestureItem.Group.allCases.count
        )
        #expect(part.contains("focusEntriesGestureRule()windowEntries"))
    }
}
