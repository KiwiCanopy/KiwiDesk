import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shortcuts overview folds (#2312): a regular digit ladder
/// and a complete mirrored set become one row; anything the user
/// changed stands alone.
@Suite("Shortcuts overview fold", .serialized)
@MainActor
struct ShortcutFoldTests {
    private let spaces = ["1", "2", "3", "4", "5"].map { SpaceID($0) }

    private func build(
        _ bindings: [(String, String)],
        icons: [SpaceID: String] = [:],
        desktops: [Int] = []
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: bindings.map {
                    KeyBinding(combo: $0.0, lua: $0.1, kind: .navigation)
                }
            ),
            spaces: spaces,
            spaceIcons: icons,
            desktops: desktops,
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
    }

    private func goTo(_ n: Int, _ combo: String? = nil) -> (String, String) {
        (
            combo ?? "control+option+\(n)",
            KeybindingCatalog.goToSpace([SpaceID("\(n)")])[0].lua
        )
    }

    private func rows(_ reference: ShortcutsReference) -> [ShortcutRow] {
        reference.controls.flatMap(\.rows)
    }

    @Test("a regular ladder folds to one row, members kept")
    func ladderFolds() throws {
        LocalizationManager.shared.select("en")
        let row = try #require(rows(build((1...3).map { goTo($0) })).first)
        #expect(row.label == "Go to Space 1–3")
        #expect(row.spokenLabel == "Go to Space 1 to 3")
        #expect(row.combo == "⌃⌥1–3")
        #expect(
            row.members.map(\.label) == [
                "Go to Space 1", "Go to Space 2", "Go to Space 3",
            ]
        )
    }

    /// A sided ladder folds with its side named once, the range
    /// spaced off the run as `ChordGlyphs` draws a chord (#2601);
    /// a ladder on two sides folds into neither.
    @Test("a sided ladder folds with its side, and sides never mix")
    func sidedLadderFolds() throws {
        LocalizationManager.shared.select("en")
        let left = (1...3).map { goTo($0, "lctrl+lalt+\($0)") }
        let row = try #require(rows(build(left)).first)
        #expect(row.combo == "Left ⌃⌥ 1–3")
        let mixed = [
            goTo(1, "lctrl+lalt+1"), goTo(2, "rctrl+ralt+2"),
            goTo(3, "lctrl+lalt+3"),
        ]
        #expect(rows(build(mixed)).allSatisfy { $0.members.isEmpty })
    }

    @Test("a rebound key or a named Space stands alone")
    func changedRowsStandAlone() {
        LocalizationManager.shared.select("en")
        let rebound = rows(
            build([
                goTo(1), goTo(2, "control+option+w"), goTo(3), goTo(4),
                goTo(5),
            ])
        )
        #expect(
            rebound.map(\.label) == [
                "Go to Space 1", "Go to Space 2", "Go to Space 3–5",
            ]
        )
        let named = rows(
            build((1...5).map { goTo($0) }, icons: [SpaceID("3"): "star"])
        )
        #expect(
            named.map(\.label) == [
                "Go to Space 1–2", "Go to Space 3", "Go to Space 4–5",
            ]
        )
    }

    @Test("an away Desktop breaks its run")
    func awayDesktopBreaks() {
        LocalizationManager.shared.select("en")
        let bindings = (1...3).map {
            (
                "control+option+command+\($0)",
                KeybindingCatalog.goToDesktop([$0])[0].lua
            )
        }
        let live = rows(build(bindings, desktops: [1, 2, 3]))
        #expect(live.map(\.label) == ["Go to Desktop 1–3"])
        // The away row leaves for the Unavailable band, and the two
        // left behind are no run.
        let away = rows(build(bindings, desktops: [1, 3]))
        #expect(away.map(\.label) == ["Go to Desktop 1", "Go to Desktop 3"])
    }

    /// The digit is judged by key code, so a layout whose number
    /// row draws other glyphs (AZERTY's "&é\"") still folds, and
    /// prints its own glyphs.
    @Test("own digit is the key code, never the drawn glyph")
    func ownDigitByKeyCode() throws {
        LocalizationManager.shared.select("en")
        let commands = KeybindingCatalog.goToSpace(
            ["1", "2", "3"].map { SpaceID($0) }
        )
        let azerty = ["&", "é", "\""]
        let tagged = commands.enumerated().map { index, command in
            var row = ShortcutRow(
                id: command.lua,
                label: command.resolvedLabel,
                combo: "⌃⌥" + azerty[index]
            )
            row.fold = ShortcutFold.tag(
                for: command,
                at: .init(family: .goToSpace, position: index + 1),
                combo: KeyCombo.parse("control+option+\(index + 1)"),
                rendered: row.combo
            )
            return row
        }
        let folded = try #require(ShortcutFold.folded(tagged).first)
        #expect(folded.combo == "⌃⌥&–\"")
        let lying = ShortcutFold.tag(
            for: commands[0],
            at: .init(family: .goToSpace, position: 1),
            combo: KeyCombo.parse("control+option+w"),
            rendered: "⌃⌥1"
        )
        #expect(lying?.ownDigit == false)
    }

    @Test("a mirrored set folds only while every member is bound")
    func setsFoldWhole() {
        LocalizationManager.shared.select("en")
        let arrows = ["left", "down", "up", "right"]
        let all = KeybindingCatalog.focusDirections.enumerated().map {
            ("control+option+\(arrows[$0.offset])", $0.element.lua)
        }
        let whole = rows(build(all))
        #expect(whole.map(\.label) == ["Focus window left, down, up, right"])
        #expect(whole.first?.combo == "⌃⌥←↓↑→")
        #expect(rows(build(Array(all.dropLast()))).count == 3)
        let width = [
            (
                "option+command+2",
                KeybindingCatalog.resizeRow(.growWidth, step: 50).lua
            ),
            (
                "option+command+1",
                KeybindingCatalog.resizeRow(.shrinkWidth, step: 50).lua
            ),
        ]
        let resize = rows(build(width))
        #expect(resize.map(\.label) == ["Shrink / grow width"])
        #expect(resize.first?.combo == "⌥⌘1 2")
        // Drawn glyphs fixed by hand: the host's layout draws its own.
        let members = ShortcutFold.sets(resizeStep: 50)
            .first { $0.0 == .width }!.1
        let punctuation = members.enumerated().map { index, command in
            var row = ShortcutRow(
                id: command.lua,
                label: command.resolvedLabel,
                combo: ["⌥⌘-", "⌥⌘="][index]
            )
            row.fold = ShortcutFold.tag(
                for: command,
                at: .init(family: .width, position: index),
                combo: KeyCombo.parse("option+command+minus"),
                rendered: row.combo
            )
            return row
        }
        #expect(ShortcutFold.folded(punctuation).first?.combo == "⌥⌘- =")
    }

    /// Each folded set lists its members in the order its label
    /// names them, which is the order its keys print in.
    @Test("a set's members keep its label's order")
    func setMembersKeepLabelOrder() {
        LocalizationManager.shared.select("en")
        let expected: [ShortcutFold.Family: [String]] = [
            .focusDirections: [
                "Focus window to the left", "Focus window below",
                "Focus window above", "Focus window to the right",
            ],
            .width: ["Shrink width", "Grow width"],
            .height: ["Shrink height", "Grow height"],
        ]
        for (family, members) in ShortcutFold.sets(resizeStep: 50) {
            let keys = ["a", "b", "c", "d"]
            let bound = members.enumerated().map {
                ("option+command+\(keys[$0.offset])", $0.element.lua)
            }
            let row = rows(build(bound)).first
            #expect(row?.members.map(\.id) == members.map(\.lua))
            if let labels = expected[family] {
                #expect(row?.members.map(\.label) == labels)
            }
        }
    }
}
