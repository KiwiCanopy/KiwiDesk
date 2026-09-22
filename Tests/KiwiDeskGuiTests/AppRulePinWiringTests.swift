import Foundation
import Testing

@testable import KiwiDesk

/// The row ASKS the decisions `AppRulePinTests` pins (#1022).
///
/// A separate suite, because the one reading what a pure function
/// answers cannot see whether anything calls it — and this change
/// shipped that exact gap for a day: deleting the pin-engaging
/// block in `setNever()`, or the setter's refusal, or the Space
/// menu's inert branch left the whole suite green with "tiling
/// requires a pin" inert (code review, 2026-09-22). Nothing
/// headless can click a `Menu`, so the whole guard is a wiring
/// guard.
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

    /// The three sites that make the rule run, each keyed on what
    /// it cannot lose rather than on its body verbatim.
    @Test("the three pin sites ask the verdict")
    func everySiteAsksTheVerdict() throws {
        let source = try facets()
        // 1. The checkbox is inert unless the verdict is `.free`,
        //    which is what dims it while tiling AND with no Space
        //    to pin to. A `!= .locked` here would ship the live
        //    checkbox that writes nothing.
        #expect(
            source.contains(
                Self.squashed("GreyOut(active: pinVerdict != .free")
            ),
            Comment(
                rawValue:
                    "the pin checkbox no longer greys on the "
                    + "verdict — either tiling stops locking it, "
                    + "or it goes live with no Space to pin to "
                    + "and silently writes nothing (#1022)"
            )
        )
        // 2. The setter refuses past the grey. A keyboard or
        //    VoiceOver route to a checkbox is not the mouse's.
        #expect(
            source.contains(
                Self.squashed("guard pinVerdict == .free else { return }")
            ),
            Comment(
                rawValue:
                    "the pin binding no longer refuses while "
                    + "locked — the store is then reachable past "
                    + "the GreyOut (#1022)"
            )
        )
        // 3. Dropping the float rule engages a pin where the row
        //    has none. This is the write; the two above are the
        //    control.
        #expect(
            source.contains(
                Self.squashed(
                    "if !isPinned, overrideBase == nil, "
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
            try facets().contains(
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

    /// The title-pattern OFFER's surfacing branches — the consult
    /// is `AppRuleTitleOfferTests`', the drawing is this one's.
    /// Deleting either `if` ships the power-user choice, and its
    /// help paragraph, to every Simple user.
    @Test("the offer gates the menu item and the help paragraph")
    func offerGatesWhatItDraws() throws {
        #expect(
            try facets().contains(Self.squashed("if offersTitles {")),
            Comment(
                rawValue:
                    "the titled menu item is no longer gated on "
                    + "the offer — every Simple user gets it "
                    + "(#1022)"
            )
        )
        #expect(
            try source("Sections/AppRulesSection.swift")
                .contains(Self.squashed("if offersTitles {")),
            Comment(
                rawValue:
                    "the `?`'s title-pattern paragraph is no "
                    + "longer gated on the offer, so it explains "
                    + "a menu item the row withholds (#1022)"
            )
        )
    }

    /// The offer's INPUT has one home too. The predicate is pure
    /// and guarded, but a second hand-assembled argument list is
    /// where the two sites drift — one forgetting the override
    /// base gives a Simple user editing a stored profile a `?`
    /// describing a choice the row withholds (architect review).
    @Test("the offer is resolved once and handed down")
    func offerIsResolvedOnce() throws {
        let row = try source("Sections/AppRuleRow.swift")
        #expect(
            row.contains(Self.squashed("let offersTitles: Bool")),
            Comment(
                rawValue:
                    "the row no longer TAKES the offer — if it "
                    + "re-derives it, its answer can disagree "
                    + "with the section's (#1022)"
            )
        )
        #expect(
            !(try facets()).contains(
                Self.squashed("AppRuleTitleOffer.isOffered")
            ),
            Comment(
                rawValue:
                    "the row assembles the offer's input again — "
                    + "there must be one copy of "
                    + "`floatRules + overrideFloatBase` (#1022)"
            )
        )
        #expect(
            try source("Sections/AppRulesSection.swift")
                .contains(
                    Self.squashed("AppRuleTitleOffer.isOffered")
                ),
            "the section resolves the offer nowhere"
        )
    }
}
