import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Float list reads a rule's app segment the way `FloatRules`
/// does — case-folded — so a hand-written mixed-case rule lists
/// against the app the engine floats (#2345).
@Suite("Float facet case folding")
struct FloatFacetCaseTests {
    private let app = "com.apple.notes"

    @Test("a mixed-case rule lists under the folded app")
    func segmentFolds() {
        #expect(FloatFacet.appSegment(of: "Com.Apple.Notes") == app)
        #expect(
            FloatFacet.appSegment(of: "Com.Apple.Notes:Draft") == app
        )
    }

    @Test("the facet reads a mixed-case rule, either side")
    func facetFolds() {
        #expect(FloatFacet.current(["Com.Apple.Notes"], app: app) == .all)
        #expect(
            FloatFacet.current(["Com.Apple.Notes:A"], app: app)
                == .titled
        )
        #expect(
            FloatFacet.current([app], app: "com.apple.Notes") == .all
        )
    }

    @Test("patterns and rules keep the fragment's case")
    func patternsFold() {
        let rules = ["Com.Apple.Notes:Draft", "other.app:X"]
        #expect(FloatFacet.patterns(rules, app: app) == ["Draft"])
        #expect(
            FloatFacet.rules(rules, app: app) == ["Com.Apple.Notes:Draft"]
        )
    }

    @Test("a write replaces the mixed-case bare rule")
    func writeFolds() {
        let rules = ["Com.Apple.Notes", "other.app"]
        #expect(
            FloatFacet.settingPatterns(["Draft"], of: app, in: rules)
                == ["other.app", "\(app):Draft"]
        )
        #expect(
            FloatFacet.settingPatterns(
                [],
                of: app,
                in: ["Com.Apple.Notes:Draft"]
            ).isEmpty
        )
    }

    @Test("the list agrees with the engine on every rule")
    func agreesWithEngine() {
        let rules = ["Com.Apple.Notes", "Org.Mozilla.Firefox:Picture"]
        let engine = FloatRules(rules)
        for rule in rules {
            let segment = FloatFacet.appSegment(of: rule)
            #expect(!engine.rules(of: segment).isEmpty)
            #expect(FloatFacet.current(rules, app: segment) != .never)
        }
    }
}
