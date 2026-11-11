import Foundation
import Testing

@testable import KiwiDesk

/// Mouse & trackpad ▸ Scroll gestures (#1656, #1519): the group
/// leads the drawer, the recorder's refusal is Core's, the travel
/// field greys while the box is off, every value row carries its
/// "Applies to" column, and each recorder's Go to reveals the
/// other's row.
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

    /// The scroll gestures open the Holding a modifier card, ahead
    /// of the modifier drags (#3184).
    @Test("the scroll entries lead the Holding a modifier card")
    func scrollGroupLeads() throws {
        let part = Self.squash(try Self.source("GesturesPart.swift"))
        #expect(
            part.contains(
                "SettingsSection(SettingsCatalog.shortcuts.gesturesModifier)"
                    + "{GesturesScrollEntries(model:model,"
            )
        )
    }

    @Test("a recorded chord is judged by Core's refusal before it lands")
    func recorderAsksCore() throws {
        // The field hands the shared recorder Core's verdict.
        let field = Self.squash(
            try Self.source("ScrollChordRecorderField.swift")
        )
        #expect(
            field.contains(
                "refuse:{ScrollChordRefusal.of($0,other:other,"
                    + "heldBy:otherGesture)"
            )
        )
        let shared = Self.squash(
            try Self.source("ModifierChordRecorder.swift")
        )
        let refusal = try #require(
            shared.range(of: "ifletfound=refuse(recorded)")
        )
        let write = try #require(shared.range(of: "chord=recorded"))
        #expect(refusal.lowerBound < write.lowerBound)
        // The refused branch leaves before the write, not only
        // ahead of it in the text.
        let branch = try #require(
            SourceScan.declarationBody(
                after: "if let found = refuse(recorded)",
                in: try Self.source("ModifierChordRecorder.swift")
            )
        )
        #expect(branch.contains("return"))
        // Nothing writes the chord ahead of the verdict, whatever
        // the spelling.
        let ahead = String(shared[..<refusal.lowerBound])
        let commit = ahead.components(separatedBy: "funccommit(").last ?? ""
        for write in ["chord=", "$chord", "_chord", "self.chord"] {
            #expect(!commit.contains(write), "\(write)")
        }
        #expect(shared.contains("mode:.modifiers"))
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
            "reachRow(.stepDistance)", "reachRow(.spaceStep)",
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

    /// The ⌃⌥⌘ entry follows the ⌃⌥ one's rows and precedes the
    /// Natural rows both gestures share.
    @Test("the Space step entry sits between the pan and Natural rows")
    func spaceStepPlacement() throws {
        let group = Self.squash(
            try Self.source("GesturesScrollEntries.swift")
        )
        let body = try #require(group.range(of: "varbody:someView{"))
        let travel = try #require(
            group.range(
                of: "reachRow(.stepDistance)",
                range: body.upperBound..<group.endIndex
            )
        )
        let step = try #require(
            group.range(
                of: "spaceStepEntry",
                range: travel.upperBound..<group.endIndex
            )
        )
        let natural = try #require(
            group.range(of: "naturalRow(.naturalTrackpad,")
        )
        #expect(step.lowerBound < natural.lowerBound)
    }

    /// Each recorder refuses the OTHER gesture's chord, and Go to
    /// reveals the row of the gesture the refusal names.
    @Test("each recorder's Go to reveals the other row")
    func goToCrosses() throws {
        let group = Self.squash(
            try Self.source("GesturesScrollEntries.swift")
        )
        #expect(
            group.contains(
                "other:gestures.spaceStep,otherGesture:.step,reveal:reveal"
            )
        )
        #expect(
            group.contains(
                "other:gestures.pan,otherGesture:.pan,reveal:reveal"
            )
        )
        let reveal = Self.squash(
            try #require(
                SourceScan.declarationBody(
                    after: "private func reveal(",
                    in: try Self.source("GesturesScrollEntries.swift")
                )
            )
        )
        #expect(reveal.contains("case.pan:Self.controls.scrollPan"))
        #expect(
            reveal.contains("case.step:Self.controls.scrollSpaceStep")
        )
        #expect(reveal.contains("model.nav.pendingReveal="))
        #expect(reveal.contains("anchor:control.id"))
        // The rows each Go to lands on are anchored there.
        for row in ["scrollSpaceStep", "scrollPan"] {
            #expect(
                group.contains(
                    ".searchAnchored(SettingsCatalog.shortcuts.gestures"
                        + ".children.\(row))"
                ),
                "\(row) has no anchor to land on"
            )
        }
    }

    /// Only the other-gesture refusal carries the link, drawn
    /// through `LinkedCaption` at the frame's slot.
    @Test("the other gesture's refusal draws Go to at its slot")
    func refusalLinks() throws {
        let field = try Self.source(
            "ScrollChordRecorderField+Refusal.swift"
        )
        let caption = Self.squash(
            try #require(
                SourceScan.declarationBody(
                    after: "func refusalCaption(",
                    in: field
                )
            )
        )
        #expect(
            caption.contains(
                "ifcase.otherGesture(letholder)=refusal,letreveal"
            )
        )
        #expect(
            caption.contains("CrossReferenceRow.split(Self.frame(refusal))")
        )
        #expect(caption.contains("navigate:{reveal(holder)}"))
        #expect(caption.contains("linkTitle:Self.goTo(holder)"))
    }

    /// Each group is a card of its own (#3184): entries inside a
    /// card are split by a `GestureRule`, a card's edge needs none,
    /// and no in-card heading is left from the one-card shape.
    @Test("each group is its own card, its entries ruled apart")
    func groupsAreCards() throws {
        let part = Self.squash(try Self.source("GesturesPart.swift"))
        #expect(!part.contains("SettingsGroupHeading("))
        #expect(!part.contains("GestureRule()}SettingsSection("))
        #expect(
            part.components(separatedBy: "SettingsSection(").count - 1
                == GestureItem.Group.allCases.count
        )
        #expect(part.contains("focusEntriesGestureRule()windowEntries"))
    }
}
