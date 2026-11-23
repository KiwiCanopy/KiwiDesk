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

    @Test("a sheet that fits keeps one column at the field's width")
    func fitsInOneColumn() {
        let model = model(cap: 2000)
        #expect(model.shortcutColumns.columns == [0..<3])
        #expect(model.sideWidth == JumpPanelRoom.fieldWidth)
    }

    /// Three 400 pt columns, their gaps and the sheet's inset,
    /// inside the default 1440 pt room's 1248 pt.
    @Test("a sheet past the room cuts into columns and widens")
    func tallSheetTakesColumns() {
        let model = model(cap: 300)
        let plan = model.shortcutColumns
        #expect(plan.columns == [0..<1, 1..<2, 2..<3])
        let width = plan.width(
            inset: JumpShortcutsView.kiwiHubInset,
            gap: ShortcutsSheetView.columnGap
        )
        #expect(model.sideWidth == width)
        #expect(width > 3 * ShortcutsColumnPlan.columnWidth)
        #expect(width <= model.room.widest)
        // A side switch keeps the room: Windows stays compact.
        #expect(model.sideWidth(for: .windows) == JumpPanelRoom.fieldWidth)
    }

    /// The plan is judged inside the scroll's vertical inset: three
    /// 242 pt sections fit two columns (500 pt) in a 510 pt sheet's
    /// room only without it.
    @Test("the columns fit inside the sheet's inset")
    func capLeavesTheInset() {
        #expect(model(cap: 510).shortcutColumns.columns.count == 3)
        #expect(model(cap: 560).shortcutColumns.columns.count == 2)
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

    @Test("a typed query re-cuts the columns")
    func queryRecuts() {
        let model = model(cap: 300)
        model.query = "app"
        #expect(model.shortcutColumns.columns == [0..<1])
        #expect(model.sideWidth == JumpPanelRoom.fieldWidth)
        model.query = "nothing matches this"
        #expect(model.shortcutColumns.columns.isEmpty)
        model.query = ""
        #expect(model.shortcutColumns.columns.count == 3)
    }
}
