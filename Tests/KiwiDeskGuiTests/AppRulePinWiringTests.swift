import Foundation
import Testing

@testable import KiwiDesk

/// The row ASKS the decisions `AppRulePinTests` pins (#1022).
///
/// A separate suite, because the one reading what a pure function
/// answers cannot see whether anything calls it — and this change
/// shipped that exact gap for a day: deleting the pin-engaging
/// block in `setNever()` or the clear button's own condition left
/// the whole suite green with "a rule must say something" inert
/// (code review, 2026-09-22). Nothing headless can click a
/// `Menu`, so the whole guard is a wiring guard.
///
/// Every clause is anchored on a CONDITION or a call, never on a
/// value a later tuning may move.
@Suite("App rule pin wiring (#1022)")
struct AppRulePinWiringTests {
    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    private func source(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/" + file
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // A read that came back empty satisfies nothing positive
        // but would fail-open every negative clause below.
        #expect(text.count > 400, "\(file) read empty")
        return Self.squashed(text)
    }

    private func facets() throws -> String {
        try source("Sections/AppRuleRow+Facets.swift")
    }

    /// The raw (comment-stripped, UNsquashed) facets source, for
    /// the brace-balanced reads below.
    private func facetsRaw() throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Sections/"
                            + "AppRuleRow+Facets.swift"
                    ),
                encoding: .utf8
            )
        )
    }

    /// The brace-balanced body of the declaration whose signature
    /// is `signature`, squashed.
    ///
    /// Scoped rather than file-wide because a file-wide needle is
    /// satisfied by a NEIGHBOUR: guard-prover cut both conditions
    /// below out of their real sites and parked them verbatim in
    /// dead properties in the same file, and every clause here
    /// stayed green while the whole of #1022 was broken
    /// (2026-09-22). The sibling suite
    /// `AppRulesAddOnSelectTests` had already paid for this on
    /// `roleLabel`; this suite did not take the lesson until it
    /// was proved twice.
    private func body(of signature: String) throws -> String {
        let raw = try facetsRaw()
        let offset = try #require(
            raw.range(of: signature),
            Comment(
                rawValue:
                    "\(signature) is gone — the decision it "
                    + "carried is wired somewhere this clause "
                    + "cannot see"
            )
        )
        var cursor = raw.distance(
            from: raw.startIndex,
            to: offset.upperBound
        )
        let found = try #require(
            SourceScan.balanced(
                Array(raw),
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "\(signature) has no balanced body to read"
        )
        return Self.squashed(found)
    }

    /// The two sites that make the rule run, each keyed on what
    /// it cannot lose rather than on its body verbatim.
    @Test("both pin sites ask the verdict")
    func everySiteAsksTheVerdict() throws {
        // Read from each site's OWN balanced body, never the
        // file — see `body(of:)`.
        let clear = try body(
            of: "private var clearPinButton: some View"
        )
        let never = try body(of: "private func setNever()")
        // 1. The clear button EXISTS only where the rule
        //    survives without a Space. Its absence is what makes
        //    "a rule must say something" visible, and it replaced
        //    a locked checkbox that had to explain itself — so
        //    there is no disabled control to reach past, and no
        //    setter refusal is owed any more (#1022, owner
        //    eyeball 2026-09-22).
        #expect(
            clear.contains(
                Self.squashed("if isPinned, pinVerdict == .optional")
            ),
            Comment(
                rawValue:
                    "the clear button no longer asks the verdict "
                    + "— either it is offered on a tiling row, "
                    + "which lets every rule fall back to saying "
                    + "nothing, or it is offered with no Space to "
                    + "clear (#1022)"
            )
        )
        // 2. Dropping the float rule engages a Space where the
        //    row has none. This is the write; the clause above is
        //    the control. It asks the verdict for the row as it
        //    will stand — tiling — so an exception the verdict
        //    grows reaches the write and the clear button alike
        //    (architect review, 2026-09-23: this used to spell
        //    the override exception a second time).
        #expect(
            never.contains(
                Self.squashed(
                    "if !isPinned, "
                        + "pinVerdict(floats: false) == .required, "
                        + "let space = prospectiveSpace"
                )
            ),
            Comment(
                rawValue:
                    "choosing \"no windows float\" no longer "
                    + "engages a pin — every tiling row can then "
                    + "rest saying nothing, which is the whole of "
                    + "#1022"
            )
        )
    }

    /// The refusal that stops `setNever` deleting the row it is
    /// editing. Anchored on the condition, because the harm is
    /// losing the user's row rather than any particular wording.
    @Test("setNever refuses rather than stranding the row")
    func setNeverRefusesWhenItCannotPin() throws {
        #expect(
            try body(of: "private func setNever()").contains(
                Self.squashed(
                    "guard pinVerdict != .unavailable "
                        + "|| isPinned else"
                )
            ),
            Comment(
                rawValue:
                    "with no Space to pin to, clearing the float "
                    + "rule leaves an app with no stored rule and "
                    + "`apps` drops the row out from under the "
                    + "user (#1022)"
            )
        )
    }

    /// The titled choice must NOT clear the float rule — that is
    /// what deleted a float-only row mid-composition. Stated as
    /// the absence it is, scoped to the arm rather than the file:
    /// `clearFloatRules` is legitimately called by the other two.
    ///
    /// The body is read BRACE-BALANCED, not as a fixed prefix. A
    /// first cut took 120 squashed characters, which ran past the
    /// end of `openTitles` into the next declaration — which is
    /// `clearFloatRules` — and reported the defect it exists to
    /// catch against correct code. A negative clause locates its
    /// subject by something the subject cannot lose (tests.md).
    @Test("opening the pattern editor clears no float rule")
    func openTitlesKeepsTheRule() throws {
        let raw = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Sections/"
                            + "AppRuleRow+Facets.swift"
                    ),
                encoding: .utf8
            )
        )
        let characters = Array(raw)
        let signature = "private func openTitles()"
        let offset = try #require(
            raw.range(of: signature),
            Comment(
                rawValue:
                    "openTitles is gone — the titled choice is "
                    + "wired somewhere this clause cannot see"
            )
        )
        var cursor = raw.distance(
            from: raw.startIndex,
            to: offset.upperBound
        )
        let body = try #require(
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "openTitles has no balanced body to read"
        )
        #expect(
            !body.contains("clearFloatRules"),
            Comment(
                rawValue:
                    "openTitles clears the float rule again — a "
                    + "float-only row's bare rule is its ONLY "
                    + "stored rule, so the row vanishes from the "
                    + "list mid-composition (#1022)"
            )
        )
        // And the menu item routes through it rather than going
        // back to calling the clearing arm directly.
        #expect(
            try facets().contains(
                Self.squashed(
                    "Button(titledLabel) { openTitles() }"
                )
            )
        )
    }

    /// The composing row stays LISTED while its editor is open,
    /// which is the other half of the same defect: the refusal
    /// above cannot help a row whose rule was already cleared.
    @Test("the composing row is unioned into the list")
    func composingRowSurvivesInTheList() throws {
        let source = try source("Sections/AppRulesSection.swift")
        #expect(
            source.contains(
                Self.squashed(
                    "if let composing = composingTitles { "
                        + "set.insert(composing) }"
                )
            ),
            Comment(
                rawValue:
                    "`apps` no longer keeps the row under "
                    + "composition — it is derived from the store, "
                    + "and a titled rule has nothing stored until "
                    + "its first pattern lands (#1022)"
            )
        )
        // And the slot is released by a deletion, or the trash
        // appears to do nothing on the row being composed.
        #expect(
            source.contains(
                Self.squashed(
                    "if composingTitles == app { composingTitles = nil }"
                )
            )
        )
    }

    /// The deletion-focus destination rides the FLOAT menu.
    ///
    /// `KeyboardActionParityTests` claims this in prose and cannot
    /// hold it: its needle is keyed on the FILE, deliberately, so
    /// that a split of `AppRuleRow` does not red it — and the cost
    /// of that refinement is that moving the destination onto the
    /// space menu, which is exactly the pre-#1022 wiring, left the
    /// whole 5765-test tree green (guard-prover, 2026-09-22). The
    /// #816 harm is a keyboard user losing their place in the list
    /// on every deletion, reintroducible in two lines.
    ///
    /// Held as an ORDER over the layout's children rather than as
    /// a contiguous run from the control. A first cut pinned the
    /// run `floatMenu.opacity(…).focused(…)` and went red the same
    /// afternoon on a `.padding` inserted between the two — a
    /// contiguous needle pins its own glue, which is the cost that
    /// shape carries. Position between two siblings is what the
    /// destination cannot lose while riding the float menu.
    @Test("the focus destination rides the float menu")
    func focusDestinationRidesTheFloatMenu() throws {
        let body = try source("Sections/AppRuleRow.swift")
        let float = try #require(
            body.range(of: "floatMenu"),
            "the row draws no float menu"
        )
        let space = try #require(
            body.range(of: "spaceMenu"),
            "the row draws no Space menu"
        )
        let focus = try #require(
            body.range(of: Self.squashed(".focused($returningRow")),
            Comment(
                rawValue:
                    "the row names no focus destination at all — "
                    + "deleting a row then drops focus out of the "
                    + "list entirely (#816)"
            )
        )
        // Two invariants in one ordering, and both matter: the
        // Space column comes FIRST ("opens in work" is the
        // headline the row leads with), and the focus destination
        // rides the float menu AFTER it. A destination moved onto
        // the Space menu lands between the two and reds here.
        #expect(
            space.lowerBound < float.lowerBound
                && float.lowerBound < focus.lowerBound,
            Comment(
                rawValue:
                    "either the columns swapped order, or the "
                    + "row's focus destination left the float "
                    + "menu — the Space menu is inert with no "
                    + "Space to open in, and a disabled control "
                    + "cannot take the assignment a deletion "
                    + "makes, so focus lands at the top of the "
                    + "window instead (#816, #1022)"
            )
        )
    }
}
