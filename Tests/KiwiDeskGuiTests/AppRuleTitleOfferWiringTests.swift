import Foundation
import Testing

@testable import KiwiDesk

/// The title-pattern offer is DRAWN where it is consulted (#1022).
///
/// `AppRuleTitleOfferTests` owns the predicate; this owns the two
/// branches that read it and the one assembly of its input. Both
/// halves shipped unguarded for a day: deleting either `if` sent
/// the power-user choice and its help paragraph to every Simple
/// user, and dropping the override base from the input left the
/// whole tree green while a Simple user editing a stored profile
/// lost an editor for patterns that were still firing
/// (guard-prover, 2026-09-22).
///
/// `AppRuleListsWiringTests` watches the lists; this one watches
/// the offer.
@Suite("App rule title offer wiring (#1022)")
struct AppRuleTitleOfferWiringTests {
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
        #expect(text.count > 400, "\(file) read empty")
        return Self.squashed(text)
    }

    private func facets() throws -> String {
        try source("Sections/AppRuleFloatRow.swift")
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
        // The `?`'s prose lives in the section's own extension,
        // split off at the §2.1 ceiling — so this clause names
        // that file, and a further split moves it again.
        #expect(
            try source("Sections/AppRulesSection+Prose.swift")
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
        let row = try facets()
        let spaceRow = try source("Sections/AppRuleSpaceRow.swift")
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
            !row.contains(
                Self.squashed("AppRuleTitleOffer.isOffered")
            )
                && !(row + spaceRow).contains(
                    Self.squashed("AppRulesGates(")
                ),
            Comment(
                rawValue:
                    "a row assembles the offer or its gates "
                    + "again — there must be one copy of the "
                    + "resolver's input (#1022)"
            )
        )
        // The one assembly, read whole. A probe that dropped the
        // override base left the WHOLE tree green (guard-prover,
        // 2026-09-22): the predicate's suite asserts it ACCEPTS
        // such a list, and nothing asserted a caller hands it one
        // — so a Simple user editing a stored profile whose base
        // carries patterns silently loses the editor.
        let section = try source("Sections/AppRulesSection.swift")
        #expect(
            section.contains(
                Self.squashed(
                    "AppRulesGates(config: model.config, "
                        + "baseFloatRules: overrideFloatBase)"
                )
            )
                && section.contains(
                    Self.squashed(
                        "AppRuleTitleOffer.isOffered("
                            + "mode: model.settingsMode, "
                            + "gates: gates)"
                    )
                ),
            Comment(
                rawValue:
                    "the offer is asked of the draft's float "
                    + "rules alone — a pattern the BASE profile "
                    + "carries is one the reader can see on this "
                    + "card, so withholding the choice strands "
                    + "them with a pattern they can neither see "
                    + "nor clear (#1022, #678 8c)"
            )
        )
        // …and handed to the Float row from that one reading.
        #expect(
            try source("Sections/AppRulesSection+Lists.swift")
                .contains(Self.squashed("offersTitles: offersTitles")),
            "the Float row is no longer handed the section's offer"
        )
    }
}
