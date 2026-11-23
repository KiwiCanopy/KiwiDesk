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
    /// once did. A compact side's sheet keeps the 488 pt ceiling.
    @Test("a compact sheet grows to 40 pt above the area, a shelf aside")
    func sheetCap() {
        func cap(_ visible: CGRect, _ area: CGRect) -> CGFloat {
            C.sheetCap(in: C.room(visible: visible, area: area), .compact)
        }
        let free = cap(visible, visible)
        let top = visible.maxY - visible.height * C.topFraction
        let ceiling = JumpPanelRoom.compactHeight
        #expect(free == min(top - 40, ceiling) - C.shortcutsChrome)
        let side = C.clearArea(
            visible: visible,
            shelves: [
                ShelfFrame(
                    frame: CGRect(x: 0, y: 0, width: 40, height: 900),
                    edge: .left
                )
            ]
        )
        #expect(cap(visible, side) == free)
        // High enough that the bottom fit, not the ceiling, binds.
        let raised = CGRect(x: 0, y: 250, width: 1440, height: 650)
        #expect(cap(visible, raised) < free)
        let tiny = CGRect(x: 0, y: 0, width: 1440, height: 300)
        #expect(cap(tiny, tiny) == 200)
    }

    /// A growing side's content runs to 48 pt above the area's
    /// bottom, past the compact ceiling (#3570 ▸ Ruling 3).
    @Test("a growing side's sheet runs to 48 pt above the area")
    func growingSheetCap() {
        let room = C.room(visible: visible, area: visible)
        let top = visible.maxY - visible.height * C.topFraction
        let grows = C.sheetCap(in: room, .grows)
        #expect(grows == top - 48 - C.shortcutsChrome)
        #expect(grows > C.sheetCap(in: room, .compact))
    }

    @Test("the panel stands in the area, its top at the field's line")
    func origin() {
        let area = CGRect(x: 40, y: 30, width: 1400, height: 870)
        let room = C.room(visible: visible, area: area)
        let point = room.origin(of: CGSize(width: 720, height: 300))
        #expect(point.x == area.midX - 360)
        #expect(point.y + 300 == room.top)
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
                modifiers: modifiers,
                hasSelection: selection
            ).leading
        }
        #expect(lit(.windows) == 0)
        #expect(lit(.windows, .shift) == 1)
        #expect(lit(.windows, .command) == 3)
        #expect(lit(.windows, [.shift, .command]) == 3)
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
                onActivate: { _ in },
                pickModifiers: { [] }
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

    /// A click acts on the hovered row, so it takes the held
    /// modifier's route or refusal from the selection, whatever it
    /// would do (#2808, amended by #2885 ▸ refusals, 6).
    @Test("the hovered row takes the held modifier's line")
    func wayHereFollowsHover() {
        func row(_ hover: JumpHover?) -> Int? {
            JumpHover.actedRow(hover: hover, selection: 0)
        }
        #expect(row(.row(2)) == 2)
        #expect(row(nil) == 0)
        #expect(row(.row(0)) == 0)
        #expect(JumpHover.actedRow(hover: nil, selection: nil) == nil)
    }

    @Test("⇧ rewrites the digits to what they then do")
    func digitHintFollowsShift() {
        LocalizationManager.shared.select("en")
        let rest = JumpFooter(scope: .windows).hints
        let shifted = JumpFooter(
            scope: .windows,
            modifiers: .shift
        ).hints
        #expect(rest[3] == "⌘1–9 Quick jump")
        #expect(shifted[3] == "⇧⌘1–9 Quick move here")
        #expect(Array(rest.prefix(3)) == Array(shifted.prefix(3)))
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
        // The Shortcuts sheet takes the cap here; the Desktops side
        // through its state's geometry (`DesktopsGeometryTests`).
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
            "letroom=Self.room(visible:visible,area:area)",
            "room:room,",
            "letwidth=room.fieldWidth",
            "setFrameOrigin(room.origin(of:panel.frame.size))",
            "anchor=CGPoint(x:panel.frame.midX,y:panel.frame.maxY)",
            // One resize per keystroke, the Shortcuts height gliding
            // (#3570 ▸ Ruling 5).
            "hosting.sizingOptions=Self.hostingSizing",
            "letglides=model?.scope==.shortcuts"
                + "DispatchQueue.main.async{self?.refit(animated:glides)}",
        ] {
            #expect(controller.contains(needle), "\(needle)")
        }
    }

    /// A refit sizes around the field row's opening place, never
    /// the frame's left edge, so the field never moves on ⇥ (#3570).
    @Test("a refit holds the field row's anchor")
    func refitHoldsTheAnchor() throws {
        let sizing = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/"
                            + "JumpPanelController+Sizing.swift"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace).joined()
        let refit = try #require(
            sizing.range(of: "funcrefit(").map {
                String(sizing[$0.lowerBound...].prefix(400))
            }
        )
        #expect(
            refit.contains(
                "JumpPanelRoom.frame(of:content.fittingSize,under:anchor)"
            )
        )
        #expect(!refit.contains("panel.frame.minX"))
    }

    /// The panel sizes only through its refit, so every path that
    /// reshapes a side's content asks for one (#3570).
    @Test("every reshaping path refits")
    func reshapesRefit() throws {
        func body(_ file: String, _ after: String) throws -> String {
            let text = SourceScan.stripComments(
                try String(
                    contentsOf: SourceScan.repoRoot(from: #filePath)
                        .appendingPathComponent(
                            "Sources/KiwiDesk/Jump/" + file
                        ),
                    encoding: .utf8
                )
            )
            return try #require(
                SourceScan.declarationBody(after: after, in: text)
            )
        }
        for (file, after) in [
            ("JumpModel+View.swift", "func reloadView()"),
            ("JumpModel+Desktops.swift", "func reloadDesktops("),
            ("JumpModel+Desktops.swift", "func refreshDesktops()"),
        ] {
            #expect(
                try body(file, after).contains("onResultsChange()"),
                "\(after)"
            )
        }
        #expect(
            try body("JumpPanelController.swift", "func settingsChanged(")
                .contains("self?.refit()")
        )
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
