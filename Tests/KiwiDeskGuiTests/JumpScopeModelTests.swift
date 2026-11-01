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
            kiwiVisionOn: false,
            items: JumpPanelController.items(
                layout: space ? layout : nil,
                profiles: ("Dual", ["Dual", "Studio"], []),
                vision: (.off, []),
                visionChord: nil,
                lensChord: { _ in nil },
                offersNewLens: true,
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

    @Test("View wraps a line and the lines on a fresh press (#2897)")
    func viewWrapsOnAFreshPress() {
        let model = model()
        model.setScope(.view)
        for _ in 0..<12 { model.handle(.side(-1), repeated: true) }
        let first = model.view?.selected?.pick
        model.handle(.side(-1), repeated: false)
        #expect(model.view?.selected?.pick != first)
        model.handle(.side(1), repeated: false)
        #expect(model.view?.selected?.pick == first)
        model.handle(.step(-1), repeated: true)
        #expect(model.view?.selection?.line == .layout)
        model.handle(.step(-1), repeated: false)
        #expect(model.view?.selection?.line != .layout)
        model.handle(.step(1), repeated: false)
        #expect(model.view?.selection?.line == .layout)
    }

    @Test("⇥ steps the sides J K L, wrapping, and clears each query")
    func tabClearsTheQuery() {
        let model = model()
        model.query = "mai"
        model.handle(.stepScope(forward: true), repeated: false)
        #expect(model.scope == .shortcuts)
        #expect(model.query == "")
        #expect(model.list.query == "")
        model.query = "flo"
        model.handle(.stepScope(forward: true), repeated: false)
        #expect(model.scope == .view)
        #expect(model.shortcuts?.query == "")
        model.query = "mon"
        model.handle(.stepScope(forward: true), repeated: false)
        #expect(model.scope == .windows)
        #expect(model.view?.query == "")
        model.handle(.stepScope(forward: false), repeated: false)
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
        model.handle(.pick(moveHere: false), repeated: false)
        model.handle(.quick(0, moveHere: false), repeated: false)
        #expect(applied.isEmpty)
        model.handle(.step(1), repeated: false)
        model.handle(.pick(moveHere: false), repeated: false)
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
        model.handle(.pick(moveHere: false), repeated: false)
        model.handle(.quick(0, moveHere: false), repeated: false)
        // ⇧⌘ digits do nothing on this side (ruling 4).
        model.handle(.quick(1, moveHere: true), repeated: false)
        #expect(applied == [.layout(.grid), .layout(LayoutMode.allCases[0])])
        model.query = "mon"
        model.handle(.escape, repeated: false)
        #expect(model.query == "")
        #expect(closed == 0)
        model.handle(.escape, repeated: false)
        #expect(closed == 1)
    }

    @Test("↓ moves to the next line, where ⌘ digits count anew")
    func linesTakeTheDigits() {
        let model = model()
        var applied: [ViewPickList.Pick] = []
        model.onApplyView = { applied.append($0) }
        model.setScope(.view)
        model.handle(.step(1), repeated: false)
        model.handle(.quick(1, moveHere: false), repeated: false)
        model.handle(.step(1), repeated: false)
        model.handle(.pick(moveHere: false), repeated: false)
        // ↓ keeps the column, clamped (#2309 ruling 11) to the
        // last chip a digit reaches, never New Lens… (#2359).
        #expect(applied == [.profile("Studio"), .vision(lens: nil)])
    }

    @Test("⌘S keeps only while Keep is armed")
    func keepWhileArmed() {
        var kept = 0
        let armed = model(keepArmed: true)
        armed.onKeep = { kept += 1 }
        armed.setScope(.view)
        armed.handle(.keep, repeated: false)
        #expect(kept == 1)
        let saved = model(keepArmed: false)
        saved.onKeep = { kept += 1 }
        saved.setScope(.view)
        saved.handle(.keep, repeated: false)
        #expect(kept == 1)
        // No profile, no Keep, whatever the drift.
        let unprofiled = model(keepArmed: true, profile: nil)
        unprofiled.onKeep = { kept += 1 }
        unprofiled.setScope(.view)
        unprofiled.handle(.keep, repeated: false)
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
        model.handle(.side(1), repeated: false)
        model.handle(.settings, repeated: false)
        model.handle(.step(1), repeated: false)
        model.handle(.settings, repeated: false)
        model.handle(.step(1), repeated: false)
        model.handle(.settings, repeated: false)
        let grid = LayoutMode.allCases.firstIndex(of: .grid)!
        #expect(
            landed == [
                .layoutDefaults(LayoutMode.allCases[grid + 1]),
                .profiles, .kiwiVision,
            ]
        )
    }
}
