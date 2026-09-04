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

    /// The ladder's POSITIONAL grammar, retuned by #1176: an
    /// arrow carries a window verb and rides either the bare
    /// base (focus) or the ⌘ tier (swap) — never ⇧, which after
    /// the retune qualifies digits alone. Nothing pinned the
    /// swap chord's base before this: moving it off ⌃⌥⇧ passed
    /// the whole suite.
    ///
    /// Derived per row rather than hand-listed, and stated as
    /// which BASES an arrow may take, so it reds on a verb
    /// changing tier and stays green when a new arrow verb joins
    /// a tier that already carries one.
    @Test("an arrow rides the base or the ⌘ tier, never ⇧")
    func arrowsRideTheirOwnTiers() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(9),
            resizeStep: 50
        )
        let arrows: Set<UInt32> = [123, 124, 125, 126]
        let base: HotkeyModifiers = [.control, .option]
        var seen = 0
        var shifted = 0
        for row in rows {
            guard let combo = KeyCombo.parse(row.combo) else {
                continue
            }
            if combo.modifiers.contains(.shift) {
                shifted += 1
                #expect(
                    !arrows.contains(combo.keyCode),
                    Comment(
                        rawValue: "⇧ on an arrow — \(row.combo) "
                            + "(\(row.label)); after #1176 it "
                            + "qualifies digits alone"
                    )
                )
            }
            guard arrows.contains(combo.keyCode) else { continue }
            seen += 1
            #expect(
                combo.modifiers == base
                    || combo.modifiers == base.union(.command),
                Comment(
                    rawValue: "arrow off its tiers — "
                        + "\(row.combo) (\(row.label))"
                )
            )
        }
        // Non-vacuity on both arms: a builder seeding no arrow
        // row, or no ⇧ row, satisfies the loops above having
        // guarded nothing.
        #expect(seen > 0, "no arrow row seeded at all")
        #expect(shifted > 0, "no ⇧ row seeded at all")
        // …and both tiers are actually in use, or "either tier"
        // is one tier wearing a disjunction.
        let bases = Set(
            rows.compactMap { KeyCombo.parse($0.combo) }
                .filter { arrows.contains($0.keyCode) }
                .map(\.modifiers)
        )
        #expect(bases == [base, base.union(.command)])
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
