import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// KiwiHub's Shortcuts side and a key sequence (#1871): an end key
/// is listed by its path, never its leader, a run it joins still
/// folds, a long path is shortened, and search reads the path's
/// names.
@Suite("Key sequences on KiwiHub (#1871)")
@MainActor
struct KeySequenceHubTests {
    private let left = KeybindingCatalog.focusDirections[0]

    private func sequence(endLua: String? = nil) -> KeyBinding {
        let end = KeyBinding(
            combo: "h",
            lua: endLua ?? left.lua,
            kind: .navigation,
            label: left.label
        )
        let branch = KeyBinding.sequence(
            combo: "w",
            label: "Windows",
            steps: [end, KeyBinding(combo: "j", kind: .navigation)]
        )
        return .sequence(
            combo: "ctrl+alt+space",
            label: "Leader",
            steps: [branch]
        )
    }

    @Test("KiwiHub lists an end key by its path, the leader not at all")
    func referenceListsPaths() {
        LocalizationManager.shared.select("en")
        var root = sequence()
        root.steps?.append(
            KeyBinding(
                combo: "t",
                lua: "print(1)",
                kind: .custom,
                desc: "Mine"
            )
        )
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: "default", bindings: [root]),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: ["default"]
        )
        let rows =
            reference.controls.flatMap(\.rows) + reference.custom
            + reference.groups.flatMap(\.rows)
        let path = SequencePathWords.drawn(["ctrl+alt+space", "w", "h"])
        #expect(
            rows.contains {
                $0.combo == path && $0.label == left.resolvedLabel
            }
        )
        // The user's Lua end key is listed by path too, never dropped.
        // The chord column speaks the path in key words.
        let spokenPath = SequencePathWords.spoken(
            ["ctrl+alt+space", "w", "h"]
        )
        #expect(rows.contains { $0.spokenChord == spokenPath })
        let lua = SequencePathWords.drawn(["ctrl+alt+space", "t"])
        #expect(rows.contains { $0.combo == lua && $0.label == "Mine" })
        #expect(rows.count == 2)
    }

    @Test("KiwiHub draws a long path shortened")
    func referenceShortensLongPaths() {
        LocalizationManager.shared.select("en")
        let deep = KeyBinding.sequence(
            combo: "ctrl+alt+space",
            label: "Leader",
            steps: [
                .sequence(
                    combo: "a",
                    steps: [
                        .sequence(
                            combo: "b",
                            steps: [
                                .sequence(
                                    combo: "c",
                                    steps: [
                                        KeyBinding(
                                            combo: "h",
                                            lua: left.lua,
                                            kind: .navigation
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: "default", bindings: [deep]),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: ["default"]
        )
        let path = ["ctrl+alt+space", "a", "b", "c", "h"]
        let rows = reference.controls.flatMap(\.rows)
        #expect(
            rows.contains { $0.combo == SequencePathWords.shortened(path) }
        )
        #expect(
            rows.contains { $0.spokenChord == SequencePathWords.spoken(path) }
        )
    }

    @Test("a path row follows a folded run, which stays whole")
    func pathFollowsTheFold() {
        LocalizationManager.shared.select("en")
        let spaces = (1...4).map { SpaceID(String($0)) }
        let go = KeybindingCatalog.goToSpace(spaces)
        // 1–3 on their own digits fold; 4 on another key does not.
        var rows = (0..<3).map { at in
            KeyBinding(
                combo: "ctrl+alt+\(at + 1)",
                lua: go[at].lua,
                kind: .navigation
            )
        }
        rows.append(
            KeyBinding(combo: "ctrl+alt+9", lua: go[3].lua, kind: .navigation)
        )
        // The path runs the run's FIRST member.
        let end = KeyBinding(combo: "1", lua: go[0].lua, kind: .navigation)
        rows.append(
            .sequence(
                combo: "ctrl+alt+space",
                label: "Leader",
                steps: [.sequence(combo: "s", label: "Spaces", steps: [end])]
            )
        )
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: "default", bindings: rows),
            spaces: spaces,
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: ["default"]
        )
        let focus = reference.controls.flatMap(\.rows)
        let path = SequencePathWords.drawn(["ctrl+alt+space", "s", "1"])
        let folds = focus.filter { !$0.members.isEmpty }
        #expect(folds.count == 1)
        #expect(folds.first?.members.count == 3)
        let folded = focus.firstIndex { !$0.members.isEmpty }
        let after = focus.firstIndex { $0.combo == path }
        #expect(folded != nil && after != nil)
        if let folded, let after {
            #expect(after == folded + 1)
            // The unfolded Space 4 row comes after the path.
            #expect(focus.indices.contains(after + 1))
            if focus.indices.contains(after + 1) {
                #expect(focus[after + 1].id == go[3].lua)
            }
        }
    }

    @Test("KiwiHub search finds a path row by a name along its path")
    func searchReadsPathNames() {
        LocalizationManager.shared.select("en")
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: "default", bindings: [sequence()]),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: ["default"]
        )
        var sheet = ShortcutsSheet(reference: reference)
        sheet.setQuery("windows")
        let rows = sheet.shown?.controls.flatMap(\.rows) ?? []
        #expect(rows.count == 1)
        #expect(rows.first?.matchedPathName == "Windows")
        sheet.setQuery("nowhere")
        #expect(sheet.matchCount == 0)
    }

}
