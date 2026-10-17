import Testing

@testable import KiwiDesk

/// The Float row's title editor writes through
/// `FloatFacet.settingPatterns` (#2103 ruling 43): the generic
/// `WindowTitleEditor` edits a list, and this is where that list
/// becomes `app:pattern` Float rules again.
@Suite("Float rule title pattern write")
struct FloatFacetPatternWriteTests {
    private let app = "com.example.app"

    @Test("the first pattern replaces the bare rule")
    func firstPatternDropsBare() {
        let rules = ["other.app", app]
        #expect(
            FloatFacet.settingPatterns(["Draft"], of: app, in: rules)
                == ["other.app", "\(app):Draft"]
        )
    }

    @Test("a removed pattern goes, the rest keep their order")
    func removeKeepsOrder() {
        let rules = ["\(app):A", "other.app", "\(app):B"]
        #expect(
            FloatFacet.settingPatterns(["B"], of: app, in: rules)
                == ["other.app", "\(app):B"]
        )
        #expect(
            FloatFacet.settingPatterns(["A", "B", "C"], of: app, in: rules)
                == rules + ["\(app):C"]
        )
    }

    @Test("removing the last pattern leaves the app no rule")
    func lastPatternGoes() {
        #expect(
            FloatFacet.settingPatterns([], of: app, in: ["\(app):A"])
                .isEmpty
        )
    }

    @Test("another app's patterns are untouched")
    func otherAppUntouched() {
        let rules = ["other.app:A", "\(app):A"]
        #expect(
            FloatFacet.settingPatterns([], of: app, in: rules)
                == ["other.app:A"]
        )
    }
}
