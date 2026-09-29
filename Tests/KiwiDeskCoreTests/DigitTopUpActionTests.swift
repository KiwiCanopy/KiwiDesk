import Foundation
import Testing

@testable import KiwiDeskCore

/// The #485 digit top-up asks which Space verb has no row, never
/// which digit is free (#1797): a reordered Space list once handed
/// Space 1 a second chord and Space 5 the digit 6.
@Suite("Digit top-up per action (#1797)")
struct DigitTopUpActionTests {
    private func ids(_ raws: [String]) -> [SpaceID] {
        raws.map { SpaceID($0) }
    }

    private func seed(_ raws: [String]) -> [KeyBinding] {
        DefaultKeybindings.bindings(spaces: ids(raws), resizeStep: 50)
    }

    private func targets(
        _ rows: [KeyBinding]
    ) -> [SpaceLuaArg.Target] {
        rows.compactMap { SpaceLuaArg.target(of: $0.lua) }
    }

    /// The owner's shape end to end: digits 1–4 bound, Space 1
    /// dragged behind others, then a top-up. Either the bound-verb
    /// skip or the own-digit rule alone keeps it green — each has
    /// its own clause below.
    @Test("a reordered list gives no Space a second chord")
    func reorderAddsNoSecondChord() {
        let existing = seed(["1", "2", "3", "4"])
        let added = DefaultKeybindings.digitTopUp(
            existing: existing,
            spaces: ids(["2", "3", "4", "6", "1", "5"])
        )
        let before = Set(targets(existing))
        #expect(
            !added.contains { row in
                SpaceLuaArg.target(of: row.lua).map(before.contains)
                    ?? false
            }
        )
    }

    @Test("a numbered Space takes its own digit wherever it sits")
    func numberedSpaceTakesItsOwnDigit() {
        let added = DefaultKeybindings.digitTopUp(
            existing: seed(["1", "2", "3", "4"]),
            spaces: ids(["2", "3", "4", "6", "1", "5"])
        )
        let five = added.filter { $0.lua.contains("(\"5\")") }
        #expect(five.count == 3)
        #expect(five.allSatisfy { $0.combo.hasSuffix("+5") })
        let six = added.filter { $0.lua.contains("(\"6\")") }
        #expect(six.allSatisfy { $0.combo.hasSuffix("+6") })
    }

    @Test("a Space that already has a verb's row is not given one")
    func boundVerbIsSkipped() {
        // Space 5 was re-recorded onto F5 by hand.
        var existing = seed(["1", "2", "3", "4"])
        existing.append(
            KeyBinding(
                combo: "control+option+f5",
                lua: "KiwiDesk.focus_space(\"5\")",
                kind: .navigation,
                label: "Go to Space 5"
            )
        )
        let added = DefaultKeybindings.digitTopUp(
            existing: existing,
            spaces: ids(["1", "2", "3", "4", "5"])
        )
        #expect(
            !added.contains {
                $0.lua == "KiwiDesk.focus_space(\"5\")"
            }
        )
        #expect(
            added.contains {
                $0.combo == "control+option+shift+5"
            }
        )
    }

    @Test("one top-up never hands one chord to two Spaces")
    func oneChordPerTopUp() {
        // A named Space in fifth place and Space 5 both want ⌃⌥5.
        let added = DefaultKeybindings.digitTopUp(
            existing: seed(["1", "2", "3", "4"]),
            spaces: ids(["1", "2", "3", "4", "Mail", "5"])
        )
        let combos = added.map(\.combo)
        #expect(combos.count == Set(combos).count)
    }
}
