import AppKit
import Combine
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

    @Test("a shelf is cut by the edge Core says it sits on")
    func shelvesCutTheArea() {
        func cut(_ frame: CGRect, _ edge: AppBarEdge) -> CGRect {
            C.clearArea(
                visible: visible,
                shelves: [ShelfFrame(frame: frame, edge: edge)]
            )
        }
        let bottom = cut(CGRect(x: 0, y: 0, width: 1440, height: 30), .bottom)
        #expect(bottom.minY == 30 && bottom.maxY == 900)
        let left = cut(CGRect(x: 0, y: 0, width: 40, height: 900), .left)
        #expect(left.minX == 40 && left.width == 1400 && left.minY == 0)
        let right = cut(CGRect(x: 1400, y: 0, width: 40, height: 900), .right)
        #expect(right.maxX == 1400 && right.minX == 0)
        let top = cut(CGRect(x: 0, y: 870, width: 1440, height: 30), .top)
        #expect(top == visible)
        // The edge decides, not the strip's shape: a square bottom
        // strip still cuts from the bottom.
        let square = cut(CGRect(x: 700, y: 0, width: 40, height: 40), .bottom)
        #expect(square.minY == 40 && square.width == 1440)
    }

    /// A side shelf narrows the panel; it never collapses the sheet
    /// to its floor, which a side strip crossing the field's span
    /// once did.
    @Test("the sheet grows to 40 pt above the area, a side shelf aside")
    func sheetCap() {
        let free = C.sheetCap(visible: visible, area: visible)
        let top = visible.maxY - visible.height * C.topFraction
        #expect(free == min(top - 40, C.maxPanelHeight) - C.shortcutsChrome)
        let side = C.clearArea(
            visible: visible,
            shelves: [
                ShelfFrame(
                    frame: CGRect(x: 0, y: 0, width: 40, height: 900),
                    edge: .left
                )
            ]
        )
        #expect(C.sheetCap(visible: visible, area: side) == free)
        // High enough that the bottom fit, not the ceiling, binds.
        let raised = CGRect(x: 0, y: 250, width: 1440, height: 650)
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
        #expect(lit(.view) == 0)
        // ⇧ moves nothing here, so nothing lights under it (#2309).
        #expect(lit(.view, .shift) == nil)
        #expect(lit(.view, .command) == 1)
        #expect(lit(.view, [.shift, .command]) == nil)
        #expect(lit(.shortcuts) == nil)
        #expect(lit(.shortcuts, .command) == nil)
        #expect(lit(.windows, selection: false) == nil)
        #expect(lit(.view, .command, selection: false) == nil)
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
                ownsShift: selected,
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

    /// A ⇧-click moves the hovered row, so it claims the way here
    /// and the selected row gives it up — unless that click moves
    /// nothing, where ⇧↩'s selection keeps it (#2808).
    @Test("the hovered row takes ⇧'s way here from the selection")
    func wayHereFollowsHover() {
        func row(_ hover: JumpHover?, moves: Set<Int> = [0, 1, 2]) -> Int? {
            JumpHover.shiftRow(
                hover: hover,
                selection: 0,
                movesHere: { moves.contains($0) }
            )
        }
        #expect(row(.row(2)) == 2)
        #expect(row(nil) == 0)
        #expect(row(.row(0)) == 0)
        #expect(row(.row(2), moves: [0]) == 0)
        #expect(
            JumpHover.shiftRow(hover: nil, selection: nil) { _ in true }
                == nil
        )
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
        let footerFile = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpPanelView+Footer.swift"
                    ),
                encoding: .utf8
            )
        )
        // Asked of the footer's own call: the rows read the same
        // flag for their way-here column.
        let footer = try #require(footerFile.range(of: "JumpFooter("))
        let call = footerFile[footer.lowerBound...].prefix(260)
        #expect(call.contains("modifiers: model.heldModifiers"))
        #expect(call.contains("hasSelection: model.hasSelection"))
        // The field shows only the typing: its placeholder always,
        // and no stand-in drawn over it.
        #expect(view.occurrences(of: "prompt: Text(fieldName)") == 1)
        // No typing drawn clear under a stand-in, in any spelling.
        #expect(view.occurrences(of: "Color.clear") == 0)
        #expect(view.occurrences(of: "fieldName }") == 0)
        #expect(view.occurrences(of: "maxHeight: model.sheetCap") == 1)
    }

    @Test("the controller hands the real shelves and area through")
    func controllerWiresTheArea() throws {
        let controller = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpPanelController.swift"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace).joined()
        for needle in [
            "shelves:core.shelfFrames()",
            "sheetCap:Self.sheetCap(visible:visible,area:area)",
            "visible:visible,area:area)",
            "Self.width(visibleWidth:area.width)",
        ] {
            #expect(controller.contains(needle), "\(needle)")
        }
    }

    @Test("the model reads its selection and held modifiers")
    func modelState() {
        let empty = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 8,
            modifiers: [.shift, .command]
        )
        #expect(!empty.hasSelection)
        #expect(empty.heldModifiers == [.shift, .command])
        let full = JumpModel(
            snapshot: JumpSnapshot(
                entries: [JumpListTests.row(1, "Safari")],
                here: nil,
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 8
        )
        #expect(full.hasSelection)
        #expect(full.heldModifiers.isEmpty)
    }

    /// A layer switch re-reads the chords while the panel shows any
    /// side, so the switch must redraw on the assignment itself.
    @Test("a re-read chord redraws the switch")
    func chordsPublish() {
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 8
        )
        var changes = 0
        let watch = model.objectWillChange.sink { changes += 1 }
        model.chords = [.windows: "⌃⌥W"]
        #expect(changes == 1)
        watch.cancel()
    }
}
