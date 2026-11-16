import Foundation
import Testing

@testable import KiwiDesk

/// Mouse & trackpad ▸ the scroll settings (#1656, #1519, #3369):
/// each value row carries its "Applies to" column, and Long swipes
/// sits at the Trackpad card's foot, greyed with its reason drawn
/// outside the grey while no two-finger swipe runs the pan.
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

    /// One checkbox under the Trackpad card's list and its footer,
    /// never on the Mouse card and never per row (#3369 ▸ Ruling).
    @Test("Long swipes sits at the Trackpad card's foot")
    func longSwipesAtTheTrackpadFoot() throws {
        let card = try Self.source("GestureListCard.swift")
        let rows = try #require(
            SourceScan.declarationBody(
                after: "private var boundRows:",
                in: card
            )
        )
        #expect(
            Self.squash(rows).contains(
                "footerifdevice==.trackpad{Divider()"
                    + "GestureLongSwipesRow(model:model)}"
            )
        )
        let users = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("Sources")
        ).filter {
            ((try? String(contentsOf: $0, encoding: .utf8)) ?? "")
                .contains("GestureLongSwipesRow(")
        }
        #expect(users.map(\.lastPathComponent) == ["GestureListCard.swift"])
    }

    /// The row asks the census gate, greys the checkbox alone, and
    /// draws its caption beside the row rather than inside the grey
    /// (gui.md ▸ a dim is not a sentence).
    @Test("Long swipes greys with its reason outside the grey")
    func longSwipesGreysWithItsReason() throws {
        let row = Self.squash(try Self.source("GestureLongSwipesRow.swift"))
        #expect(
            row.contains(".inertReason(for:.shortcuts(.scrollLongSwipes))")
        )
        #expect(row.contains("grey:greyed?Self.caption:nil"))
        #expect(row.contains("ifgreyed{Text(Self.caption)"))
        #expect(!row.contains("GreyOut("))
    }

    @Test("every value row carries its Applies to column")
    func everyRowReaches() throws {
        let row = try Self.source("GestureLongSwipesRow.swift")
        // The step length is Lua-only (#1873 ▸ Ruling 2026-11-16).
        #expect(row.contains("ScrollGestureField.longSwipes"))
        #expect(row.contains("model.scrollReach(field.rawValue)"))
        #expect(row.contains("family: .scroll"))
        #expect(Self.squash(row).contains("reach:{reach}"))
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
