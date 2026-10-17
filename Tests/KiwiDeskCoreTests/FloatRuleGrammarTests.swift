import Testing

@testable import KiwiDeskCore

/// A float rule's grammar has one reading, `FloatRules.parse`,
/// which every other reading derives from (#2345): the app folded,
/// the fragment kept, a bare colon no title rule.
@Suite("Float rule grammar")
struct FloatRuleGrammarTests {
    @Test("parse folds the app and keeps the fragment")
    func parseReadsTheGrammar() {
        let bare = FloatRules.parse("Com.Apple.Notes")
        #expect(bare.app == "com.apple.notes")
        #expect(bare.title == nil)
        let titled = FloatRules.parse("Com.Apple.Notes:Draft A")
        #expect(titled.app == "com.apple.notes")
        #expect(titled.title == "Draft A")
        // Only the first colon splits; the fragment keeps the rest.
        #expect(FloatRules.parse("app:a:b").title == "a:b")
    }

    /// A rule ending in a bare colon carries no fragment, so the
    /// engine floats it as an app of that name — and so does every
    /// reader, the Float list's `isTitled` included.
    @Test("a bare colon is no title rule")
    func bareColonIsAnApp() {
        let parsed = FloatRules.parse("Foo:")
        #expect(parsed.app == "foo:")
        #expect(parsed.title == nil)
        #expect(FloatRules.title(of: ":X") == nil)
        #expect(FloatRules.app(of: ":X") == ":x")
    }

    @Test("every reading derives from parse")
    func readingsAgree() {
        for rule in ["Foo", "Foo:Bar", "Foo:", ":Bar", "a:b:c"] {
            let parsed = FloatRules.parse(rule)
            #expect(FloatRules.app(of: rule) == parsed.app)
            #expect(FloatRules.title(of: rule) == parsed.title)
            #expect(
                FloatRules.normalizedRule(rule)
                    == FloatRules.rule(app: parsed.app, title: parsed.title)
            )
            #expect(
                FloatRules([rule]).rawRules
                    == [FloatRules.normalizedRule(rule)]
            )
        }
    }
}
