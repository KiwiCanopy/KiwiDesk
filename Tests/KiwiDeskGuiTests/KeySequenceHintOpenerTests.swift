import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// An end key that opens KiwiHub is a sequence action like any
/// other, so the hint panel lists it, while KiwiHub's own Shortcuts
/// side still leaves the openers to its side switch (#3695 ▸
/// Ruling, #2246). `.serialized` as the Lua-owned panel suites are.
@Suite("Key sequence hint openers (#3695)", .serialized)
@MainActor
struct KeySequenceHintOpenerTests {
    private func core() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-hint-open-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try """
        KiwiDesk.define_sequence("ctrl+alt+space", {
          w = { fn = function() kiwihub.show("windows") end,
                name = "Switcher" },
          m = { fn = function() KiwiDesk.cycle_mode() end, name = "Mode" },
        }, { name = "Leader" })
        """.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return core
    }

    /// Every key row, a folded row's members counted one by one.
    private func keyRows(_ reference: ShortcutsReference) -> Int {
        let rows =
            reference.controls.flatMap(\.rows)
            + reference.groups.flatMap(\.rows) + reference.apps
            + reference.custom + reference.inactive
        return rows.reduce(0) { $0 + max($1.members.count, 1) }
    }

    @Test("a hint step lists an end key that opens KiwiHub")
    func hintListsTheOpener() throws {
        LocalizationManager.shared.select("en")
        let core = try core()
        let controller = KeySequenceHintController(core: core)
        controller.follow(
            KeySequenceProgress(leader: "ctrl+alt+space", path: [])
        )
        defer { controller.follow(nil) }
        let (hint, reference) = try #require(controller.hint())
        let endKeys = Set(hint.endKeys.bindings.map(\.combo))
        #expect(endKeys == ["w", "m"])
        let step = try #require(reference)
        #expect(keyRows(step) == 2)
        // Control: the Shortcuts side's build of the same step
        // still drops the opener.
        let side = ShortcutsReferenceBuilder.build(
            layer: hint.endKeys,
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [hint.endKeys.name]
        )
        #expect(keyRows(side) == 1)
    }
}
