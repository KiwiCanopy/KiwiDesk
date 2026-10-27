import Foundation
import Testing

@testable import KiwiDeskCore

/// What each MODIFIER means in the seeded ladder (#1094) — split
/// from `DefaultKeybindingsTests`, which owns the seed's shape
/// (combos parse, rows are unique, digits map to positions).
/// This suite owns the senses those combos carry, which is a
/// different question and the one #1094 settled: `⇧` qualifies a
/// positional row, or is a ruled related variant of its unshifted
/// twin (#1655, #453, #2675), and each sticky scope takes the
/// letter its own rationale gives it.
@Suite("The seeded ladder's modifier senses (#1094)")
struct DefaultKeybindingLadderTests {
    private func spaces(_ count: Int) -> [SpaceID] {
        (1...count).map { SpaceID($0) }
    }

    /// The ruled related variants: an unshifted row → its `⇧` twin,
    /// which reverses it or acts on the same subject. A new pair is
    /// a ruling (profiles.md ▸ seeded keymap), its reason beside it.
    private static let relatedVariants:
        [String: (shifted: String, why: String)] = [
            "KiwiDesk.focus_space_back()": (
                "KiwiDesk.focus_space_forward()",
                "reverses the history step, as ⇧Tab (#1655)"
            ),
            "KiwiDesk.cycle_mode()": (
                "KiwiDesk.cycle_mode(\"prev\")",
                "reverses the layout cycle (#453)"
            ),
            "KiwiDesk.pocket()": (
                "KiwiDesk.toggle_pocket_window()",
                "marks the window the plain key pockets (#2675)"
            ),
        ]

    /// Whether `row` is the ruled `⇧` variant of its seeded twin.
    private func isRelatedVariant(
        _ combo: KeyCombo,
        _ row: KeyBinding,
        in combos: [(KeyCombo, KeyBinding)]
    ) -> Bool {
        var plain = combo.modifiers
        plain.remove(.shift)
        let twin = combos.first {
            $0.0.keyCode == combo.keyCode && $0.0.modifiers == plain
        }?.1
        return twin.flatMap { Self.relatedVariants[$0.lua]?.shifted }
            == row.lua
    }

    @Test("⇧ on a letter is only a ruled variant of its twin")
    func shiftNeverQualifiesALetter() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(9),
            resizeStep: 50,
            base: .standard
        )
        // The ladder spends ⇧ on "act on the window", which only
        // ever qualifies a POSITIONAL row — an arrow or a digit.
        // A lettered row is a toggle or app chrome and escalates
        // nothing, so a ⇧ on one would be the second sense of ⇧
        // that #1094 retired with `⌃⌥⇧S` — save a ruled related
        // variant of its twin: the reversal of a stepping twin
        // (`⌃⌥⇧C`, #453) or an act on the same subject (`⌃⌥⇧P`,
        // #2675). Derived from each
        // row's own key rather than a hand-listed set, so a
        // toggle added later joins the invariant by existing.
        let combos = rows.compactMap { row in
            KeyCombo.parse(row.combo).map { ($0, row) }
        }
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
            #expect(
                !isLetter || isRelatedVariant(combo, row, in: combos),
                "⇧ on a lettered row — \(site)"
            )
        }
        // Non-vacuity: a builder that emitted no ⇧ row at all
        // would satisfy the loop above without guarding anything
        // (rule-authoring.md — a guard asserts its input is
        // non-empty before asserting anything about it).
        #expect(shifted > 0, "no ⇧ row seeded at all")
    }

    /// The ladder's POSITIONAL grammar, retuned by #1655 (owner
    /// ruling 2026-10-09): an arrow rides the bare base (focus),
    /// `⇧` (act on the window — swap, as `⇧` sends it on a
    /// digit), or `⌘` (step the Spaces, the ⌃⌥⌘ + scroll base).
    /// A `⇧` arrow is a window verb and a `⌘` arrow a Space verb,
    /// derived per row rather than hand-listed, so a verb changing
    /// tier reds here and a new arrow verb joining a tier that
    /// already carries its kind stays green.
    @Test("an arrow rides its tier: base focus, ⇧ swap, ⌘ Spaces")
    func arrowsRideTheirOwnTiers() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(9),
            resizeStep: 50,
            base: .standard
        )
        let arrows: Set<UInt32> = [123, 124, 125, 126]
        let base: HotkeyModifiers = [.control, .option]
        var tiers: Set<HotkeyModifiers> = []
        for row in rows {
            guard let combo = KeyCombo.parse(row.combo),
                arrows.contains(combo.keyCode)
            else { continue }
            tiers.insert(combo.modifiers)
            let site = "\(row.combo) (\(row.label))"
            switch combo.modifiers {
            case base:
                #expect(row.lua.hasPrefix("KiwiDesk.focus("), "\(site)")
            case base.union(.shift):
                #expect(
                    row.lua.hasPrefix("KiwiDesk.swap("),
                    "⇧ on an arrow acts on the window — \(site)"
                )
            case base.union(.command):
                #expect(
                    row.lua.hasPrefix("KiwiDesk.focus_space_"),
                    "⌘ on an arrow steps the Spaces — \(site)"
                )
            default:
                Issue.record("arrow off its tiers — \(site)")
            }
        }
        // Every tier in use, or "its tier" is fewer tiers wearing
        // a switch — and a builder seeding no arrow at all would
        // pass the loop above having looked at nothing.
        #expect(
            tiers == [base, base.union(.shift), base.union(.command)]
        )
    }

    /// Off a positional key `⇧` is a related variant of its twin —
    /// its reversal, as on Tab everywhere on macOS (#1655, widened
    /// to the layout cycle's `C` by #453), or an act on the same
    /// subject (#2675). So a `⇧` row on any key that is neither an
    /// arrow nor a digit has its unshifted twin seeded, and the
    /// pair is ruled in `relatedVariants`.
    @Test("off a positional key, ⇧ is a ruled variant of its twin")
    func shiftIsARelatedVariant() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(9),
            resizeStep: 50,
            base: .standard
        )
        let combos = rows.compactMap { row in
            KeyCombo.parse(row.combo).map { ($0, row) }
        }
        let positional: Set<UInt32> = Set(
            ["left", "right", "up", "down"]
                + (0...9).map(String.init)
        ).reduce(into: []) { set, name in
            if let code = KeyCombo.keyCodes[name] { set.insert(code) }
        }
        #expect(positional.count == 14, "key names moved")
        var reversed = 0
        for (combo, row) in combos
        where combo.modifiers.contains(.shift)
            && !positional.contains(combo.keyCode)
        {
            reversed += 1
            #expect(
                isRelatedVariant(combo, row, in: combos),
                "⇧ on \(row.combo) is no ruled variant of its twin"
            )
        }
        // Every ruled pair is seeded, or the register outgrew it.
        #expect(reversed == Self.relatedVariants.count)
    }

    @Test("sticky seeds ⌃⌥S global; ⌃⌥P is Pocket, pin unseeded")
    func stickyToggleLetters() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(9),
            resizeStep: 50,
            base: .standard
        )
        let byLua = Dictionary(
            rows.map { ($0.lua, $0.combo) },
            uniquingKeysWith: { a, _ in a }
        )
        // S takes the UNQUALIFIED verb, matching the label a
        // GUI-first user is shown; P is Pocket's since #2446, and
        // pin keeps no default chord.
        #expect(
            byLua["KiwiDesk.toggle_sticky()"]
                == "control+option+s"
        )
        #expect(byLua["KiwiDesk.pocket()"] == "control+option+p")
        #expect(byLua["KiwiDesk.toggle_display_sticky()"] == nil)
    }
}
