import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The three-sided key panel's shape (#2246): where it may stand
/// beside KiwiShelf, how tall the Shortcuts sheet grows, what the
/// footer leads with, and a field that shows only the typing.
@Suite("The key panel's shape")
@MainActor
struct JumpPanelShapeTests {
    private typealias C = JumpPanelController
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test("a shelf on any edge but the top is cut from the area")
    func shelvesCutTheArea() {
        let bottom = CGRect(x: 0, y: 0, width: 1440, height: 30)
        #expect(C.clearArea(visible: visible, shelves: [bottom]).minY == 30)
        let left = CGRect(x: 0, y: 0, width: 40, height: 900)
        let leftCut = C.clearArea(visible: visible, shelves: [left])
        #expect(leftCut.minX == 40 && leftCut.width == 1400)
        #expect(leftCut.minY == 0)
        let right = CGRect(x: 1400, y: 0, width: 40, height: 900)
        #expect(C.clearArea(visible: visible, shelves: [right]).maxX == 1400)
        let top = CGRect(x: 0, y: 870, width: 1440, height: 30)
        #expect(C.clearArea(visible: visible, shelves: [top]) == visible)
    }

    /// A side shelf narrows the panel; it never collapses the sheet
    /// to its floor, which a side strip crossing the field's span
    /// once did.
    @Test("the sheet grows to 40 pt above the area, a side shelf aside")
    func sheetCap() {
        let free = C.sheetCap(visible: visible, area: visible)
        let top = visible.maxY - visible.height * C.topFraction
        #expect(free == min(top - 40, 720) - C.shortcutsChrome)
        let side = C.clearArea(
            visible: visible,
            shelves: [CGRect(x: 0, y: 0, width: 40, height: 900)]
        )
        #expect(C.sheetCap(visible: visible, area: side) == free)
        let raised = CGRect(x: 0, y: 200, width: 1440, height: 700)
        #expect(C.sheetCap(visible: visible, area: raised) < free)
        let tiny = CGRect(x: 0, y: 0, width: 1440, height: 300)
        #expect(C.sheetCap(visible: tiny, area: tiny) == 200)
    }

    @Test("the panel stands in the area, its top at the field's line")
    func origin() {
        let area = CGRect(x: 40, y: 30, width: 1400, height: 870)
        let point = C.origin(
            size: CGSize(width: 720, height: 2000),
            visible: visible,
            area: area
        )
        #expect(point.x == area.midX - 360)
        #expect(point.y == 30)
    }

    /// One hint lit: the pick that acts on the selection with the
    /// modifiers held now (owner ruling 2026-10-13, #2246).
    @Test("the footer lights the one live pick")
    func footerLeads() {
        func lit(
            _ scope: JumpScope,
            _ modifiers: NSEvent.ModifierFlags = [],
            selection: Bool = true
        ) -> Int? {
            JumpFooter(
                scope: scope,
                overflows: false,
                modifiers: modifiers,
                hasSelection: selection
            ).leading
        }
        #expect(lit(.windows) == 0)
        #expect(lit(.windows, .shift) == 1)
        #expect(lit(.windows, .command) == 2)
        #expect(lit(.windows, [.shift, .command]) == 2)
        #expect(lit(.layouts) == 1)
        #expect(lit(.layouts, .shift) == 1)
        #expect(lit(.layouts, .command) == 2)
        #expect(lit(.layouts, [.shift, .command]) == 2)
        #expect(lit(.shortcuts) == nil)
        #expect(lit(.shortcuts, .command) == nil)
        #expect(lit(.windows, selection: false) == nil)
        #expect(lit(.layouts, .command, selection: false) == nil)
    }

    /// ⇧ alone moves the selected row; ⇧⌘ reaches every numbered
    /// row through its digit, so each shows its way here.
    @Test("the way here follows the chord's reach")
    func wayHereFollowsReach() throws {
        let entry = JumpListTests.row(1, "Safari")
        let match = try #require(JumpSearch.matches([entry], query: "").first)
        let here = JumpRowText.Place(glyph: nil, text: "Space 2")
        func shows(
            selected: Bool,
            number: Int?,
            command: Bool,
            shift: Bool
        ) -> Bool {
            JumpRowView(
                match: match,
                icon: nil,
                isSelected: selected,
                number: number,
                commandHeld: command,
                shiftHeld: shift,
                wayHere: here,
                onActivate: { _ in }
            ).showsWayHere
        }
        #expect(shows(selected: true, number: 1, command: false, shift: true))
        #expect(
            !shows(selected: false, number: 2, command: false, shift: true)
        )
        #expect(shows(selected: false, number: 2, command: true, shift: true))
        #expect(
            !shows(selected: false, number: nil, command: true, shift: true)
        )
        #expect(!shows(selected: true, number: 1, command: true, shift: false))
    }

    @Test("⇧ rewrites the digits to what they then do")
    func digitHintFollowsShift() {
        LocalizationManager.shared.select("en")
        let rest = JumpFooter(scope: .windows, overflows: false).hints
        let shifted = JumpFooter(
            scope: .windows,
            overflows: false,
            modifiers: .shift
        ).hints
        #expect(rest[2] == "⌘1–9 Quick jump")
        #expect(shifted[2] == "⇧⌘1–9 Quick move here")
        #expect(rest[0] == shifted[0] && rest[1] == shifted[1])
    }

    @Test("the footer and the field read the model")
    func wiring() throws {
        let view = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpPanelView.swift"
                    ),
                encoding: .utf8
            )
        )
        // Asked of the footer's own call: the rows read the same
        // flag for their way-here column.
        let footer = try #require(view.range(of: "JumpFooter("))
        let call = view[footer.lowerBound...].prefix(260)
        #expect(call.contains("modifiers: model.heldModifiers"))
        #expect(call.contains("hasSelection: model.hasSelection"))
        // The field shows only the typing: its placeholder always,
        // and no stand-in drawn over it.
        #expect(
            view.occurrences(of: "prompt: Text(model.scope.fieldName)") == 1
        )
        #expect(view.occurrences(of: ".foregroundStyle(Color.clear)") == 0)
        #expect(view.occurrences(of: "fieldName }") == 0)
        #expect(view.occurrences(of: "maxHeight: model.sheetCap") == 1)
    }
}
