import Foundation
import KiwiDeskCore
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
        let body = try #require(
            SourceScan.declarationBody(after: "var body:", in: card)
        )
        // After the rows and their footer, outside their reveal.
        #expect(
            Self.squash(body).contains(
                "revealed(boundRows)ifdevice==.trackpad{GestureRule()"
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

    /// The footer takes the gesture rows' columns (#3401): its icon
    /// on their icon, its reach on theirs, its caption on their
    /// pop-ups, and its recorder space the recorder's own layout.
    @Test("Long swipes lines up with the gesture rows")
    func longSwipesTakesTheRowColumns() throws {
        let row = Self.squash(try Self.source("GestureLongSwipesRow.swift"))
        #expect(row.contains("columns:.gestures,"))
        #expect(row.contains(".padding(.leading,GestureListRow.textIndent)"))
        let shape = Self.squash(
            SourceScan.stripComments(
                try String(
                    contentsOf: Self.root.appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Keybindings/ShortcutSettingRow.swift"
                    ),
                    encoding: .utf8
                )
            )
        )
        let gestures = try #require(
            shape.components(separatedBy: "privatevargesturesRow:")
                .dropFirst().first
        )
        let columns: [String] = [
            "someView{HStack(spacing:GestureListRow.rowGap){",
            "HStack(spacing:GestureListRow.columnGap){",
            "Color.clear.frame(width:GestureListRow",
            ".disclosureWidth,height:1)",
            "IconGlyphLabel(icon:Self.settingGlyph)",
            ".frame(width:GestureIcon.width)",
            ".accessibilityHidden(true)titled}",
            "Spacer(minLength:GestureListRow.rowGap)reach",
            "GestureChordRecorder.footprint.overlay{control}",
            "AppRuleDeleteButton.slot}}",
        ]
        let needle = columns.joined()
        #expect(gestures.hasPrefix(needle))
        // The row it lines up with: the same columns, in order.
        let list = Self.squash(try Self.source("GestureListRow.swift"))
        let listRow: [String] = [
            "HStack(spacing:Self.rowGap){HStack(spacing:Self.columnGap){",
            "disclosureSlotGestureIcon(input:key.input)",
            "gesturePickeractionContainer}",
            "Spacer(minLength:Self.rowGap)reachColumn",
            "GestureChordRecorder(",
        ]
        #expect(list.contains(listRow.joined()))
        // The recorder, then the trash, and nothing after them.
        let tail = try #require(
            list.components(separatedBy: "GestureChordRecorder(")
                .dropFirst().first
        )
        let trash = "armsOnAppear:armsOnAppear)AppRuleDeleteButton("
        #expect(tail.contains(trash))
        let recorder = Self.squash(
            try Self.source("GestureChordRecorder.swift")
        )
        #expect(
            recorder.contains("HStack(spacing:6){recordButtonclearButton}")
        )
        #expect(
            recorder.contains(
                "HStack(spacing:6){KeyRecorderField.recordWell(\"\"){}"
                    + "Color.clear.frame(width:KeyRecorderField"
                    + ".iconSlotWidth)}"
            )
        )
        #expect(
            recorder.contains(
                "Color.clear.frame(width:KeyRecorderField.iconSlotWidth)"
                    + ".overlay{"
            )
        )
    }

    /// The gate answers both sides: the seeded ⌃⌥ focus swipe
    /// reaches Long swipes, and with it unbound nothing does.
    @Test("the Long swipes gate answers both sides")
    func longSwipesGateAnswers() {
        let key = SettingKey.shortcuts(.scrollLongSwipes)
        var config = GuiConfig()
        #expect(ShortcutsGates(config: config).inertReason(for: key) == nil)
        config.gesture[GestureKey(.swipe2, GestureSeeds.panKeys)] = .unbound
        #expect(
            ShortcutsGates(config: config).inertReason(for: key)
                == .noPanSwipe
        )
    }

    /// The runner hands the pan exactly the families the gate reads,
    /// so the grey cannot disagree with what a swipe does (#3369).
    @Test("the runner dispatches the pan on runsThePan")
    func runnerReadsThePredicate() throws {
        let url = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/App/KiwiCore+GestureRunner.swift"
        )
        let runner = try #require(
            SourceScan.declarationBody(
                after: "private func runScroll(",
                in: SourceScan.stripComments(
                    try String(contentsOf: url, encoding: .utf8)
                )
            )
        )
        let squashed = Self.squash(runner)
        #expect(
            squashed.contains(
                "case.family(letfamily)wherefamily.runsThePan:"
                    + "handleScrollPan(event,session:session.pan,"
                    + "directional:family==.focus)"
            )
        )
        #expect(!squashed.contains("case.family(.focus)"))
        #expect(!squashed.contains("case.family(.walk)"))
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
