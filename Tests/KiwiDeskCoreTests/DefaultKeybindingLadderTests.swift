import Foundation
import Testing

@testable import KiwiDeskCore

/// What each MODIFIER means in the seeded ladder (#1094) — split
/// from `DefaultKeybindingsTests`, which owns the seed's shape
/// (combos parse, rows are unique, digits map to positions).
/// This suite owns the senses those combos carry, which is a
/// different question and the one #1094 settled: `⇧` qualifies a
/// positional row and nothing else, and each sticky scope takes
/// the letter its own rationale gives it.
@Suite("The seeded ladder's modifier senses (#1094)")
struct DefaultKeybindingLadderTests {
    private func spaces(_ count: Int) -> [SpaceID] {
        (1...count).map { SpaceID($0) }
    }

    @Test("⇧ carries one meaning: no lettered row spends it")
    func shiftNeverQualifiesALetter() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(9),
            resizeStep: 50
        )
        // The ladder spends ⇧ on "act on the window", which only
        // ever qualifies a POSITIONAL row — an arrow or a digit.
        // A lettered row is a toggle or app chrome and escalates
        // nothing, so a ⇧ on one would be the second sense of ⇧
        // that #1094 retired with `⌃⌥⇧S`. Derived from each row's
        // own key rather than a hand-listed set, so a toggle
        // added later joins the invariant by existing.
        var shifted = 0
        for row in rows {
            guard let combo = KeyCombo.parse(row.combo),
                combo.modifiers.contains(.shift),
                let key = KeyCombo.keyName(for: combo.keyCode)
            else { continue }
            shifted += 1
            let isLetter =
                key.count == 1 && key.allSatisfy(\.isLetter)
            let site = "\(row.combo) (\(row.label))"
            #expect(!isLetter, "⇧ on a lettered row — \(site)")
        }
        // Non-vacuity: a builder that emitted no ⇧ row at all
        // would satisfy the loop above without guarding anything
        // (rule-authoring.md — a guard asserts its input is
        // non-empty before asserting anything about it).
        #expect(shifted > 0, "no ⇧ row seeded at all")
    }

    @Test("sticky seeds ⌃⌥S global and ⌃⌥P screen-scoped")
    func stickyToggleLetters() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(9),
            resizeStep: 50
        )
        let byLua = Dictionary(
            rows.map { ($0.lua, $0.combo) },
            uniquingKeysWith: { a, _ in a }
        )
        // S takes the UNQUALIFIED verb, matching the label a
        // GUI-first user is shown; P names the `pin.fill` mark
        // rather than the label, so no translation can orphan it.
        #expect(
            byLua["KiwiDesk.toggle_sticky()"]
                == "control+option+s"
        )
        #expect(
            byLua["KiwiDesk.toggle_display_sticky()"]
                == "control+option+p"
        )
    }
}
