import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The key panel's two scopes (#2229 ▸ Ruling): ⇥ switches and
/// clears both queries, Layouts reads its Space fresh on entry, and
/// its keys apply, keep and land in Layout Defaults.
@Suite("Jump to window scopes")
@MainActor
struct JumpScopeModelTests {
    private func model(keepArmed: Bool = true) -> JumpModel {
        let model = JumpModel(
            snapshot: JumpSnapshot(
                entries: [JumpListTests.row(1, "Mail", "Inbox")],
                here: "1",
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 8
        )
        model.loadLayouts = { _ in
            LayoutPickList(
                state: LayoutPickerState(
                    space: "3",
                    live: .grid,
                    drifted: keepArmed,
                    profile: "Dual",
                    keepArmed: keepArmed
                ),
                names: JumpPanelController.layoutNames
            )
        }
        return model
    }

    @Test("⇥ switches scope and clears the query on both sides")
    func tabClearsTheQuery() {
        let model = model()
        model.query = "mai"
        model.handle(.toggleScope)
        #expect(model.scope == .layouts)
        #expect(model.query == "")
        #expect(model.list.query == "")
        model.query = "mon"
        model.handle(.toggleScope)
        #expect(model.scope == .windows)
        #expect(model.layouts?.query == "")
    }

    @Test("Layouts stays out of reach where its Space is gone")
    func goneSpaceStaysOnWindows() {
        let model = model()
        model.loadLayouts = { _ in nil }
        model.handle(.toggleScope)
        #expect(model.scope == .windows)
    }

    @Test("↩ and ⌘ digits apply, Esc clears then closes")
    func layoutsKeys() {
        let model = model()
        var applied: [LayoutMode] = []
        var closed = 0
        model.onApply = { applied.append($0) }
        model.onClose = { closed += 1 }
        model.setScope(.layouts)
        model.handle(.pick(moveHere: false))
        model.handle(.quick(0, moveHere: false))
        #expect(applied == [.grid, LayoutMode.allCases[0]])
        model.query = "mon"
        model.handle(.escape)
        #expect(model.query == "")
        #expect(closed == 0)
        model.handle(.escape)
        #expect(closed == 1)
    }

    @Test("⌘S keeps only while Keep is armed")
    func keepWhileArmed() {
        var kept = 0
        let armed = model(keepArmed: true)
        armed.onKeep = { kept += 1 }
        armed.setScope(.layouts)
        armed.handle(.keep)
        #expect(kept == 1)
        let saved = model(keepArmed: false)
        saved.onKeep = { kept += 1 }
        saved.setScope(.layouts)
        saved.handle(.keep)
        #expect(kept == 1)
    }

    @Test("⌘, lands on the selected tile's layout")
    func layoutDefaultsTakesTheSelection() {
        let model = model()
        var landed: [LayoutMode] = []
        model.onLayoutDefaults = { landed.append($0) }
        model.setScope(.layouts)
        model.handle(.side(1))
        model.handle(.layoutDefaults)
        let grid = LayoutMode.allCases.firstIndex(of: .grid)!
        #expect(landed == [LayoutMode.allCases[grid + 1]])
    }

    @Test("the field names the selected layout and what ↩ does")
    func fieldPreview() {
        LocalizationManager.shared.select("en")
        let model = model()
        model.setScope(.layouts)
        model.query = "mon"
        let field = model.field
        let name = field.map { String($0.name.characters) }
        #expect(name == "Monocle")
        #expect(field?.frame == "%1$@ — Apply")
    }
}

/// The selection follows the pointer on a real move only (#2229 ▸
/// designer ruling): a row or tile sliding under a still pointer —
/// the panel opening there, a re-rank — moves nothing.
@Suite("Jump to window hover")
@MainActor
struct JumpHoverTests {
    private func model() -> JumpModel {
        JumpModel(
            snapshot: JumpSnapshot(
                entries: [
                    JumpListTests.row(1, "Mail", "Inbox"),
                    JumpListTests.row(2, "Notes", "Ideas"),
                ],
                here: "1",
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 8,
            pointer: CGPoint(x: 10, y: 10)
        )
    }

    @Test("a still pointer selects nothing, a moved one selects")
    func movementOnly() {
        let model = model()
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 10))
        #expect(model.list.selection == 0)
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        #expect(model.list.selection == 1)
        // The list re-ranks under the same pointer: no move.
        model.query = "mail"
        model.hoverRow(0, pointer: CGPoint(x: 10, y: 30))
        #expect(model.list.selection == 0)
    }

    @Test("a tile hover moves the selection, never the current mark")
    func tileHover() {
        let model = model()
        model.loadLayouts = { _ in
            LayoutPickList(
                state: LayoutPickerState(
                    space: "3",
                    live: .grid,
                    drifted: false,
                    profile: nil,
                    keepArmed: false
                ),
                names: JumpPanelController.layoutNames
            )
        }
        model.setScope(.layouts)
        model.hoverTile(.stack, pointer: CGPoint(x: 40, y: 10))
        #expect(model.layouts?.selected == .stack)
        #expect(model.layouts?.state.live == .grid)
        // A row hover reaches nothing while Layouts shows.
        model.hoverRow(1, pointer: CGPoint(x: 50, y: 10))
        #expect(model.list.selection == 0)
    }
}
