import AppKit
import ApplicationServices
import Testing

@testable import KiwiDeskCore

/// Float rules reach KiwiDesk's marked own window like any app's
/// (#2059): nothing forces its float, so detection asks the rules
/// with its title — and that title now names the area it shows. A
/// bare bundle rule floats it on every area; a title-fragment rule
/// floats it only while the area it names is shown.
@Suite("Float rules on the own window (#2059)")
struct OwnWindowFloatRuleTests {
    private let bundle = "app.kiwidesk.test"

    private func verdict(
        title: String,
        rules: [String]
    ) -> FloatVerdict {
        EventLoop.composeVerdict(
            .facts(
                WindowFacts(
                    role: kAXWindowRole,
                    subrole: kAXStandardWindowSubrole,
                    layer: 0
                ) { title }
            ),
            pid: getpid(),
            activationPolicy: .regular,
            tilesAsOwnWindow: true,
            bundleID: bundle,
            rules: FloatRules(rules)
        )
    }

    @Test("A title-fragment rule follows the shown area")
    func titleRuleFollowsTheArea() {
        let rule = ["\(bundle):Shortcuts"]
        #expect(
            verdict(title: "Shortcuts & Gestures", rules: rule)
                == .floats(.rule)
        )
        #expect(verdict(title: "Settings", rules: rule) == .tiles)
    }

    @Test("A bundle rule floats every area")
    func bundleRuleFloatsEveryArea() {
        for title in ["Settings", "Shortcuts & Gestures", "General"] {
            #expect(
                verdict(title: title, rules: [bundle]) == .floats(.rule)
            )
        }
    }

    @Test("Without a rule the marked window tiles on every area")
    func noRuleTiles() {
        for title in ["Settings", "Shortcuts & Gestures"] {
            #expect(verdict(title: title, rules: []) == .tiles)
        }
    }
}
