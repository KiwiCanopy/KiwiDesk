import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk

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

    @Test("⇧ moves the footer's lead from Jump to Move here")
    func footerLeads() {
        #expect(JumpFooter(scope: .windows, overflows: false).leading == 0)
        #expect(
            JumpFooter(scope: .windows, overflows: false, shiftHeld: true)
                .leading == 1
        )
        #expect(
            JumpFooter(scope: .shortcuts, overflows: false, shiftHeld: true)
                .leading == nil
        )
        #expect(JumpFooter(scope: .layouts, overflows: false).leading == nil)
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
        let call = view[footer.lowerBound...].prefix(160)
        #expect(call.contains("shiftHeld: model.shiftHeld"))
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
