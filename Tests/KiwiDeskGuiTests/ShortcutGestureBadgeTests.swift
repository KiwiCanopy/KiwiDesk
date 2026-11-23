import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shortcuts panel's gestures (#1873 ▸ Ruling 2026-11-15): a
/// gesture whose action has a row is a badge on it, the most
/// specific first; every other binding is a row of one Gestures
/// group, so each appears once; a search naming one brings it
/// forward.
@MainActor
@Suite("Shortcuts panel gesture badges")
struct ShortcutGestureBadgeTests {
    private let hyper: ScrollChord = [.control, .option]
    private let step: ScrollChord = [.control, .option, .command]
    private let next = "KiwiDesk.focus_space_next()"

    private func reference(_ rows: [ShortcutRow]) -> ShortcutsReference {
        ShortcutsReference(
            layerName: "default",
            controls: [ShortcutSubgroup(title: "Spaces", rows: rows)],
            apps: [],
            custom: []
        )
    }

    private func build(
        _ bindings: [GestureKey: GestureAction],
        rows: [ShortcutRow]
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.withGestures(
            reference(rows),
            bindings: bindings,
            command: { _ in nil }
        )
    }

    @Test("a row wears the ladder's gesture first, the alias behind it")
    func ladderLeads() throws {
        let built = build(
            [
                GestureKey(.swipe2, step): .family(.space),
                GestureKey(.swipe3, hyper): .split(
                    GestureSplit(axes: [.leftRight: .space], arms: [:])
                ),
                // Fewer keys, but a mouse: the trackpad still leads.
                GestureKey(.wheelX, [.control]): .family(.space),
            ],
            rows: [ShortcutRow(id: next, label: "Go to next Space", combo: "")]
        )
        let row = try #require(built.controls.first?.rows.first)
        #expect(row.gestures.count == 3)
        #expect(row.gestures.first?.key == GestureKey(.swipe3, hyper))
        #expect(row.gestures.first?.direction == .left)
    }

    @Test("a binding no row holds lands once in the Gestures group")
    func leftoversGroup() throws {
        let built = build(
            [
                GestureKey(.drag, [.control, .command]): .grab(.move),
                GestureKey(.tap4): .run(LuaAction(lua: "kiwivision.toggle()")),
            ],
            rows: []
        )
        let group = try #require(built.groups.last)
        #expect(group.rows.count == 2)
        #expect(group.rows.allSatisfy { $0.gestures.count == 1 })
    }

    /// Two gestures that run one command, with no row of keys to
    /// sit on, make one Gestures row wearing both badges, as a keyed
    /// row does (owner, 2026-11-23).
    @Test("a command two gestures reach is one Gestures row")
    func oneRowPerCommand() throws {
        let overview = LuaAction(lua: "kiwihub.show(\"desktops\")")
        let built = build(
            [
                GestureKey(.tap4): .run(overview),
                GestureKey(.swipe4, [.control]): .split(
                    GestureSplit(axes: [:], arms: [.up: overview])
                ),
                GestureKey(.tap3): .run(LuaAction(lua: "kiwivision.toggle()")),
            ],
            rows: []
        )
        let group = try #require(built.groups.last)
        #expect(group.rows.count == 2)
        let merged = try #require(
            group.rows.first { $0.gestures.count == 2 }
        )
        #expect(
            Set(merged.gestures.map { $0.key.input })
                == Set([GestureInput.tap4, .swipe4])
        )
        #expect(
            merged.gestures
                == merged.gestures.sorted(
                    by: ShortcutGestureBadge.moreSpecific
                )
        )
    }

    /// A binding a row badges is held there alone, never also left
    /// for the Gestures group.
    @Test("a badged binding is not left over")
    func badgedIsNotLeftOver() {
        let built = build(
            [GestureKey(.swipe2, step): .family(.space)],
            rows: [
                ShortcutRow(id: next, label: "Go to next Space", combo: ""),
                ShortcutRow(
                    id: "KiwiDesk.focus_space_previous()",
                    label: "Go to previous Space",
                    combo: ""
                ),
            ]
        )
        #expect(
            built.controls.first?.rows.allSatisfy { !$0.gestures.isEmpty }
                == true
        )
        #expect(
            built.groups.allSatisfy { $0.rows.allSatisfy(\.gestures.isEmpty) }
        )
    }

    @Test("a search naming a hidden gesture brings it forward")
    func searchBringsForward() throws {
        let built = build(
            [
                GestureKey(.swipe2, step): .family(.space),
                GestureKey(.swipe3, hyper): .family(.space),
            ],
            rows: [ShortcutRow(id: next, label: "Go to next Space", combo: "")]
        )
        let row = try #require(built.controls.first?.rows.first)
        let alias = try #require(row.gestures.last)
        let hit = try #require(
            ShortcutsSheet.matched(row, by: alias.words)
        )
        #expect(hit.gestures.first == alias)
    }
}
