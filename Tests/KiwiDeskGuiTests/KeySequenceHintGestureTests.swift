import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The hint panel lists a step's branches and end keys alone: no
/// gesture badge on a key and no gesture-only row (#3428 ▸ Ruling),
/// while KiwiHub's sheet over the same core keeps both (#3380).
/// `.serialized` as the Lua-owned panel suites are.
@Suite("Key sequence hint gestures (#3428)", .serialized)
@MainActor
struct KeySequenceHintGestureTests {
    private func core() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-hint-gest-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        // A gesture on the step's own command, and one on a command
        // no key holds, which KiwiHub lists as a gesture-only row.
        try """
        KiwiDesk.define_sequence("ctrl+alt+space", {
          m = { fn = "KiwiDesk.cycle_mode()", name = "Mode" },
        }, { name = "Leader" })
        gesture.bind("tap5", "", "KiwiDesk.cycle_mode()")
        gesture.bind("swipe3", "control+option", "focus")
        """.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return core
    }

    private func rows(_ reference: ShortcutsReference) -> [ShortcutRow] {
        reference.controls.flatMap(\.rows) + reference.groups.flatMap(\.rows)
            + reference.apps + reference.custom + reference.inactive
            + reference.desktopAway
    }

    @Test("a step's hint reference carries no gesture")
    func hintHasNoGesture() throws {
        LocalizationManager.shared.select("en")
        let core = try core()
        // Positive control: the sheet over this core draws gestures.
        let hub = try #require(
            JumpPanelController.reference(core: core, gestures: true)
        )
        #expect(rows(hub).contains { !$0.gestures.isEmpty })
        let controller = KeySequenceHintController(core: core)
        controller.follow(
            KeySequenceProgress(leader: "ctrl+alt+space", path: [])
        )
        let (hint, reference) = try #require(controller.hint())
        #expect(hint.endKeys.bindings.map(\.combo) == ["m"])
        let step = try #require(reference)
        #expect(!rows(step).isEmpty)
        #expect(rows(step).allSatisfy { $0.gestures.isEmpty })
        #expect(rows(step).allSatisfy { !$0.combo.isEmpty })
        controller.follow(nil)
    }
}
