import AppKit
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts side over its columns (#3570 ▸ Ruling 5, amended
/// with the ui-designer 2026-11-23): the model cuts the sheet the
/// room cannot hold in one column, the panel widens to those
/// columns, and the keys stay a reference sheet's — ↑ ↓ and the
/// Page keys scroll the one shared scroll view, ← → stay with the
/// field's text, and nothing is selected.
@Suite("Shortcuts columns in the model")
@MainActor
struct ShortcutsColumnKeysTests {
    private static func rows(
        _ prefix: String,
        _ count: Int
    ) -> [ShortcutRow] {
        (1...count).map {
            ShortcutRow(
                id: "\(prefix)\($0)",
                label: "\(prefix) \($0)",
                combo: "⌃⌥X"
            )
        }
    }

    /// Two eight-row groups and the Apps section: three sections.
    private static let reference = ShortcutsReference(
        layerName: KeyLayer.defaultName,
        controls: [
            ShortcutSubgroup(title: "Focus", rows: rows("Focus", 8)),
            ShortcutSubgroup(title: "Move", rows: rows("Move", 8)),
        ],
        inactive: [],
        desktopAway: [],
        apps: rows("App", 8),
        custom: []
    )

    /// A model on the Shortcuts side whose sheet room is `cap`.
    private func model(cap: CGFloat) -> JumpModel {
        LocalizationManager.shared.select("en")
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 9,
            sheetCap: cap
        )
        model.loadShortcuts = { Self.reference }
        model.setScope(.shortcuts)
        return model
    }

    /// Rows in reading order, as `section × 100 + row`.
    private func order(_ plan: ShortcutsColumnPlan) -> [Int] {
        plan.columns.joined().flatMap { piece in
            piece.rows.map { piece.section * 100 + $0 }
        }
    }

    private var threeWide: CGFloat {
        ShortcutsColumnPlan.width(
            columns: 3,
            inset: JumpShortcutsView.kiwiHubInset,
            gap: ShortcutsSheetView.columnGap
        )
    }

    @Test("a sheet that fits keeps one column at the field's width")
    func fitsInOneColumn() {
        let model = model(cap: 2000)
        #expect(model.shortcutColumns.columns.count == 1)
        #expect(model.sideWidth == JumpPanelRoom.fieldWidth)
    }

    /// Three columns at the 400 pt pitch and the sheet's inset: the
    /// most the default 1440 pt room's 1248 pt holds.
    @Test("a sheet past the room cuts into columns and widens")
    func tallSheetTakesColumns() {
        let model = model(cap: 300)
        #expect(model.shortcutColumns.columns.count == 3)
        #expect(model.sideWidth == threeWide)
        #expect(threeWide <= model.room.widest)
        // A side switch keeps the room: Windows stays compact.
        #expect(model.sideWidth(for: .windows) == JumpPanelRoom.fieldWidth)
    }

    /// The count is judged inside the scroll's vertical inset: the
    /// three 242 pt sections, 758 pt as one column, fit a 782 pt
    /// sheet's room but not a 770 pt one's.
    @Test("the count fits inside the sheet's inset")
    func capLeavesTheInset() {
        #expect(model(cap: 782).shortcutColumns.columns.count == 1)
        #expect(model(cap: 770).shortcutColumns.columns.count == 3)
    }

    /// The model takes its caps from the room the controller hands
    /// it: a growing side's, never the compact ceiling.
    @Test("the model's caps come from its room")
    func capsFromTheRoom() {
        let room = JumpPanelController.room(
            visible: CGRect(x: 0, y: 0, width: 1600, height: 1000),
            area: CGRect(x: 0, y: 0, width: 1600, height: 1000)
        )
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 9,
            room: room
        )
        #expect(
            model.sheetCap == JumpPanelController.sheetCap(in: room, .grows)
        )
        #expect(model.panelWidth == room.fieldWidth)
    }

    /// One column is judged at the field row's wrap: a captioned
    /// sheet that fits one wide column stays whole, though its
    /// caption would wrap taller in a narrow one.
    @Test("one column is judged at the field row's width")
    func singleAtTheFieldWidth() throws {
        LocalizationManager.shared.select("en")
        let captioned = ShortcutsReference(
            layerName: KeyLayer.defaultName,
            controls: [
                ShortcutSubgroup(title: "Focus", rows: Self.rows("Focus", 4))
            ],
            inactive: Self.rows("Gone", 4),
            desktopAway: [],
            apps: [],
            custom: []
        )
        let wide =
            JumpPanelRoom.fieldWidth - 2 * JumpShortcutsView.kiwiHubInset
        let sections = ShortcutsSheetView.sections(captioned)
        let heights = sections.map {
            ShortcutsSheetView.planned($0, needle: "", width: wide).height
        }
        let tall = ShortcutsColumnPlan.height(heights)
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 9,
            sheetCap: tall + 2 * JumpShortcutsView.kiwiHubVerticalInset
        )
        model.loadShortcuts = { captioned }
        model.setScope(.shortcuts)
        #expect(model.shortcutColumns.columns.count == 1)
    }

    @Test("↑ ↓ and the Page keys scroll the one shared scroll view")
    func keysScroll() {
        let model = model(cap: 300)
        model.handle(.step(1), repeated: false)
        #expect(model.sheetScroll.lines == 1)
        model.handle(.page(-1), repeated: false)
        #expect(model.sheetScroll.pages == -1)
        #expect(model.sheetScroll.serial == 2)
        // ← → reach nothing on this side: no selection to move.
        model.handle(.side(1), repeated: false)
        #expect(model.sheetScroll.serial == 2)
    }

    /// ← → stay with the field's text, so the caret moves through
    /// a typed query.
    @Test("← → stay with the field")
    func arrowsStayWithTheField() {
        for code: UInt16 in [123, 124] {
            #expect(
                JumpKey.of(
                    keyCode: code,
                    modifiers: [],
                    scope: .shortcuts,
                    naming: false
                ) == nil
            )
        }
    }

    /// Typing never changes the width or the count: the filtered
    /// rows rebalance across the same columns (ui-designer,
    /// 2026-11-23), here one 8-row section split across all three.
    @Test("typing keeps the width and the columns")
    func typingKeepsTheShape() {
        let model = model(cap: 300)
        model.query = "app"
        let plan = model.shortcutColumns
        #expect(plan.columns.count == 3)
        #expect(plan.columns.allSatisfy { !$0.isEmpty })
        #expect(order(plan) == (0..<8).map { $0 })
        #expect(plan.columns[1].first?.continued == true)
        #expect(model.sideWidth == threeWide)
        model.query = "nothing matches this"
        #expect(model.shortcutColumns.columns.isEmpty)
        #expect(model.sideWidth == threeWide)
        model.query = ""
        #expect(model.shortcutColumns.columns.count == 3)
    }

    /// ⇥ away and back sets the shape afresh for what the side
    /// shows then.
    @Test("each entry sets the shape afresh")
    func entrySetsTheShape() {
        let model = model(cap: 300)
        #expect(model.sideWidth == threeWide)
        model.loadShortcuts = {
            ShortcutsReference(
                layerName: KeyLayer.defaultName,
                controls: [],
                inactive: [],
                desktopAway: [],
                apps: Self.rows("App", 2),
                custom: []
            )
        }
        model.setScope(.windows)
        model.setScope(.shortcuts)
        #expect(model.shortcutColumns.columns.count == 1)
        #expect(model.sideWidth == JumpPanelRoom.fieldWidth)
    }

    /// The closing section's room counts when the side opens, at
    /// the width one column draws it: a sheet whose columns fit
    /// alone takes three once Unavailable stands below them.
    @Test("the closing section's room decides the count")
    func closingDecides() {
        LocalizationManager.shared.select("en")
        let inset = JumpShortcutsView.kiwiHubInset
        let single = JumpPanelRoom.fieldWidth - 2 * inset
        let plain = ShortcutsSheetView.sections(Self.reference).map {
            ShortcutsSheetView.planned($0, needle: "", width: single).height
        }
        let fits =
            ShortcutsColumnPlan.height(plain)
            + 2 * JumpShortcutsView.kiwiHubVerticalInset
        #expect(model(cap: fits).shortcutColumns.columns.count == 1)
        var away = Self.reference
        away.desktopAway = Self.rows("Away", 2)
        let model = model(cap: fits)
        model.loadShortcuts = { away }
        model.setScope(.windows)
        model.setScope(.shortcuts)
        #expect(model.shortcutColumns.columns.count == 3)
    }

    /// Unavailable closes the sheet across its width, below the
    /// columns: the plan cuts the other sections only.
    @Test("Unavailable stands below the columns")
    func unavailableCloses() {
        LocalizationManager.shared.select("en")
        var reference = Self.reference
        reference.desktopAway = Self.rows("Away", 3)
        let model = model(cap: 300)
        model.loadShortcuts = { reference }
        model.setScope(.windows)
        model.setScope(.shortcuts)
        let flowing = ShortcutsSheetView.sections(reference)
            .filter { !$0.closes }
        #expect(flowing.count == 3)
        #expect(
            ShortcutsSheetView.sections(reference).last?.closes == true
        )
        #expect(
            model.shortcutColumns.columns.joined().allSatisfy {
                $0.section < flowing.count
            }
        )
        #expect(order(model.shortcutColumns).count == 24)
    }
}
