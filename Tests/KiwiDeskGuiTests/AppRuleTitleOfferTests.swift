import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The App Rules half of the #678 8c capability unlock — the
/// third of the family, after `ShortcutsCapabilityUnlockTests`
/// and `SpaceOverrideUnlockTests`, and it pins the same three
/// properties those two name.
///
/// The defect this closes (#1022): the float menu offered
/// "floats when titled…" to everybody. Matching windows by a
/// fragment of the title is power-user work — you have to know
/// your app's window titles, and that the test is a *contains* —
/// and it sat one click from the two choices a newcomer wants.
///
/// The trap, stated by both sibling suites and equally live here:
/// the cheapest implementation gates on the MODE alone. That
/// passes any test that only ever checks Simple-with-nothing and
/// Power-User-with-nothing, and it silently strands a Simple user
/// who already has patterns — they could neither see nor clear
/// them. Every test below names which property it holds.
///
/// One property is deliberately NOT tested, because a test of it
/// would assert what the type system already says (tests.md,
/// "Not owed"): that the gate cannot alter what runs.
/// `isOffered` returns `Bool` and touches nothing, and the
/// pattern editor's own visibility is `floatFacet == .titled ||
/// editingTitles` — it never reads this predicate, so a withheld
/// offer cannot hide an existing pattern.
@Suite("App Rule title-pattern unlock (#1022)")
struct AppRuleTitleOfferTests {
    /// Three apps, so "the whole list" has peers to be wrong
    /// about — a single-app fixture would pass this suite while a
    /// per-row gate shipped.
    private let plainRules = [
        "com.apple.finder",
        "com.apple.mail",
        "com.apple.safari",
    ]

    /// Asks the offer through the area resolver, as the section
    /// does: `rules` are the draft's float rules, `base` the
    /// override base's.
    private func offered(
        _ mode: SettingsMode,
        _ rules: [String],
        base: [String]? = nil
    ) -> Bool {
        var config = GuiConfig()
        config.floatRules = rules
        return AppRuleTitleOffer.isOffered(
            mode: mode,
            gates: AppRulesGates(
                config: config,
                baseFloatRules: base
            )
        )
    }

    // MARK: - The offer is withheld until it is earned

    @Test("Simple with no pattern anywhere withholds the offer")
    func simpleWithoutPatternsIsLocked() {
        #expect(
            !offered(.simple, plainRules)
        )
        // And with no float rules at all — the state a fresh
        // install is in.
        #expect(
            !offered(.simple, [])
        )
    }

    @Test("Power User always offers it, patterns or not")
    func powerUserIsAlwaysOffered() {
        #expect(
            offered(.powerUser, [])
        )
    }

    // MARK: - The whole list, not the row that earned it

    /// The property a per-row gate breaks: one app's pattern
    /// unlocks the choice on EVERY row, including the two apps
    /// that carry none.
    ///
    /// Asserted by handing the predicate the whole list while only
    /// the middle app has a pattern — a gate written as
    /// `patterns(for: thisRow).isEmpty == false` answers false for
    /// the other two and would fail here.
    @Test("one pattern unlocks the offer for every app")
    func onePatternUnlocksTheWholeList() {
        var rules = plainRules
        rules[1] = "com.apple.mail:Drafts"
        #expect(
            offered(.simple, rules),
            "a pattern on Mail must unlock Finder's row too"
        )
        // And it is the LIST that is consulted, not one app:
        // asking with only a patternless app present is the
        // locked answer, so the true above came from the list
        // rather than from the mode leaking through.
        #expect(
            !offered(.simple, [rules[0]]),
            "a list with no pattern in it stays locked"
        )
    }

    /// The "collapsing away when the last pattern is cleared"
    /// half — a state a per-row gate cannot express at all.
    @Test("clearing the last pattern re-locks the offer")
    func clearingTheLastPatternRelocks() {
        var rules = ["com.apple.finder:Get Info"]
        #expect(
            offered(.simple, rules)
        )
        rules = ["com.apple.finder"]
        #expect(
            !offered(.simple, rules),
            "the offer must collapse with the last pattern"
        )
    }

    // MARK: - The mode never changes what runs

    /// A Simple user who already has patterns must still reach
    /// them — this is the arm the mode-only gate strands, and the
    /// reason the predicate consults saved state rather than the
    /// mode alone.
    @Test("saved patterns stay reachable in Simple")
    func savedPatternsStayReachableInSimple() {
        #expect(
            offered(.simple, ["com.apple.finder:Get Info"]),
            "a Simple user with patterns must still reach them"
        )
    }

    /// And a pattern the OVERRIDE BASE carries counts, because
    /// that is a pattern the reader can see on the card while
    /// editing a stored profile. The resolver unions the two
    /// lists for exactly this; a base-only pattern with an empty
    /// draft is how that union is asserted to matter.
    @Test("a base profile's pattern unlocks the offer too")
    func overrideBasePatternUnlocks() {
        #expect(
            offered(.simple, [], base: ["com.apple.mail:Drafts"])
        )
    }

    /// A bundle identifier cannot contain a colon, so the colon IS
    /// the pattern marker — the same split `FloatFacet` reads. A
    /// rule with a colon and an EMPTY pattern is still a pattern
    /// rule as far as the storage goes, and the offer must agree
    /// with `FloatFacet`, not with a prettier reading of it.
    @Test("the marker is the colon, as FloatFacet reads it")
    func markerAgreesWithFloatFacet() {
        let rule = "com.apple.finder:Get Info"
        #expect(
            FloatFacet.current([rule], app: "com.apple.finder")
                == .titled
        )
        #expect(
            offered(.simple, [rule])
        )
    }
}
