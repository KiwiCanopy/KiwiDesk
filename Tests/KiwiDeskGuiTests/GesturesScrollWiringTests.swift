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

    /// A group's end is a rule, not a missing one: every heading
    /// after the first sits under a `GestureRule` and stands off
    /// it; the first, under the card's own hairline, takes none.
    @Test("groups close with a rule, and later headings stand off it")
    func groupsClose() throws {
        let drawer = Self.squash(try Self.source("GesturesDrawer.swift"))
        let headings =
            drawer.components(separatedBy: "GestureGroupHeading(")
            .count - 1
        #expect(headings == 3)
        #expect(
            drawer.components(
                separatedBy: "GestureRule()GestureGroupHeading("
            ).count - 1 == headings - 1
        )
        #expect(
            drawer.components(separatedBy: "followsGroup:true").count - 1
                == headings - 1
        )
        let first = try #require(drawer.range(of: "GestureGroupHeading("))
        #expect(
            !drawer[..<first.lowerBound].hasSuffix("GestureRule()")
        )
    }
}
