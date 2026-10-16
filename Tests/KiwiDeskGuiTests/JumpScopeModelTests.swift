import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's sides (#2229, #2309): ⇥ switches and clears every
/// query, View reads its lines fresh on entry and is always
/// reachable, and its keys apply, keep and land in Settings.
@Suite("Jump to window scopes")
@MainActor
struct JumpScopeModelTests {
    static func viewList(
        space: Bool = true,
        keepArmed: Bool = true,
        profile: String? = "Dual"
    ) -> ViewPickList {
        let layout = LayoutPickerState(
            space: "3",
            live: .grid,
            drifted: keepArmed,
            profile: profile,
            keepArmed: keepArmed
        )
        return ViewPickList(
            layout: space ? layout : nil,
            items: JumpPanelController.items(
                layout: space ? layout : nil,
                profiles: ("Dual", ["Dual", "Studio"], []),
                vision: (.off, []),
                visionChord: nil,
                inert: nil
            )
        )
    }

    private func model(
        space: Bool = true,
        keepArmed: Bool = true,
        profile: String? = "Dual"
    ) -> JumpModel {
        let model = JumpModel(
            snapshot: JumpSnapshot(
                entries: [JumpListTests.row(1, "Mail", "Inbox")],
                here: "1",
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 8,
            pointer: .zero
        )
        model.currentPointer = { .zero }
        model.loadView = {
            Self.viewList(space: space, keepArmed: keepArmed, profile: profile)
        }
        return model
    }

    @Test("⇥ steps the sides J K L, wrapping, and clears each query")
    func tabClearsTheQuery() {
        let model = model()
        model.query = "mai"
        model.handle(.stepScope(forward: true))
        #expect(model.scope == .shortcuts)
        #expect(model.query == "")
        #expect(model.list.query == "")
        model.query = "flo"
        model.handle(.stepScope(forward: true))
        #expect(model.scope == .view)
        #expect(model.shortcuts?.query == "")
        model.query = "mon"
        model.handle(.stepScope(forward: true))
        #expect(model.scope == .windows)
        #expect(model.view?.query == "")
        model.handle(.stepScope(forward: false))
        #expect(model.scope == .view)
    }

    /// Profile and KiwiVision need no Space, so the side opens
    /// with the Layout line greyed rather than being stepped past.
    @Test("View opens with no Space, its layouts greyed")
    func noSpaceGreysTheLayouts() {
        let model = model(space: false)
        var applied: [ViewPickList.Pick] = []
        model.onApplyView = { applied.append($0) }
        model.setScope(.view)
        #expect(model.scope == .view)
        #expect(model.view?.selection?.line == .layout)
        model.handle(.pick(moveHere: false))
        model.handle(.quick(0, moveHere: false))
        #expect(applied.isEmpty)
        model.handle(.step(1))
        model.handle(.pick(moveHere: false))
        #expect(applied == [.profile("Dual")])
    }

    @Test("↩ and ⌘ digits apply, Esc clears then closes")
    func viewKeys() {
        let model = model()
        var applied: [ViewPickList.Pick] = []
        var closed = 0
        model.onApplyView = { applied.append($0) }
        model.onClose = { closed += 1 }
        model.setScope(.view)
        model.handle(.pick(moveHere: false))
        model.handle(.quick(0, moveHere: false))
        // ⇧⌘ digits do nothing on this side (ruling 4).
        model.handle(.quick(1, moveHere: true))
        #expect(applied == [.layout(.grid), .layout(LayoutMode.allCases[0])])
        model.query = "mon"
        model.handle(.escape)
        #expect(model.query == "")
        #expect(closed == 0)
        model.handle(.escape)
        #expect(closed == 1)
    }

    @Test("↓ moves to the next line, where ⌘ digits count anew")
    func linesTakeTheDigits() {
        let model = model()
        var applied: [ViewPickList.Pick] = []
        model.onApplyView = { applied.append($0) }
        model.setScope(.view)
        model.handle(.step(1))
        model.handle(.quick(1, moveHere: false))
        model.handle(.step(1))
        model.handle(.pick(moveHere: false))
        #expect(applied == [.profile("Studio"), .vision(lens: nil)])
    }

    @Test("⌘S keeps only while Keep is armed")
    func keepWhileArmed() {
        var kept = 0
        let armed = model(keepArmed: true)
        armed.onKeep = { kept += 1 }
        armed.setScope(.view)
        armed.handle(.keep)
        #expect(kept == 1)
        let saved = model(keepArmed: false)
        saved.onKeep = { kept += 1 }
        saved.setScope(.view)
        saved.handle(.keep)
        #expect(kept == 1)
        // No profile, no Keep, whatever the drift.
        let unprofiled = model(keepArmed: true, profile: nil)
        unprofiled.onKeep = { kept += 1 }
        unprofiled.setScope(.view)
        unprofiled.handle(.keep)
        #expect(kept == 1)
    }

    @Test("⌘, lands on the selected line's page")
    func settingsTakesTheLine() {
        let model = model()
        var landed: [SettingsLanding] = []
        model.onViewSettings = { line, item in
            landed.append(
                JumpPanelController.landing(line, item?.pick, live: .grid)
            )
        }
        model.setScope(.view)
        model.handle(.side(1))
        model.handle(.settings)
        model.handle(.step(1))
        model.handle(.settings)
        model.handle(.step(1))
        model.handle(.settings)
        let grid = LayoutMode.allCases.firstIndex(of: .grid)!
        #expect(
            landed == [
                .layoutDefaults(LayoutMode.allCases[grid + 1]),
                .profiles, .kiwiVision,
            ]
        )
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
        model.currentPointer = { CGPoint(x: 10, y: 30) }
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 10))
        #expect(model.list.selection == 0)
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        #expect(model.list.selection == 1)
        // The list re-ranks under the same pointer: no move.
        model.query = "i"
        #expect(model.list.results.count == 2)
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        #expect(model.list.selection == 0)
    }

    /// The pointer moved where no row hears it — the field, the
    /// footer — then the list re-ranked under it: no move.
    @Test("a re-rank under a pointer moved off the rows selects nothing")
    func reRankAfterOffRowMove() {
        let model = model()
        var pointer = CGPoint(x: 10, y: 10)
        model.currentPointer = { pointer }
        pointer = CGPoint(x: 300, y: 5)
        model.query = "i"
        model.hoverRow(1, pointer: pointer)
        #expect(model.list.selection == 0)
    }

    @Test("an item hover moves the selection, never the current mark")
    func tileHover() {
        let model = model()
        model.loadView = { JumpScopeModelTests.viewList() }
        model.currentPointer = { CGPoint(x: 10, y: 10) }
        model.setScope(.view)
        model.hoverItem(.layout(.stack), pointer: CGPoint(x: 40, y: 10))
        #expect(model.view?.selected?.pick == .layout(.stack))
        #expect(model.view?.layout?.live == .grid)
        model.hoverItem(.vision(lens: nil), pointer: CGPoint(x: 60, y: 30))
        #expect(model.view?.selected?.pick == .vision(lens: nil))
        // A row hover reaches nothing while Layouts shows.
        model.hoverRow(1, pointer: CGPoint(x: 50, y: 10))
        #expect(model.list.selection == 0)
    }
}
