import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A titled Space rule (#3341): which rule a title picks, and that
/// one beats the app's bare rule at a window's creation. Brave's
/// titles are the measured shape, `<tab> - Brave – <profile>`.
@Suite("Titled Space rules (#3341)")
struct TitledSpaceRulesTests {
    private let brave = "com.brave.browser"

    private func rules(_ pairs: [String: String]) -> TitledSpaceRules {
        TitledSpaceRules(pairs.mapValues { SpaceID($0) })
    }

    @Test("the longest matching fragment wins")
    func longestWins() {
        let set = rules([
            "\(brave):Brave": "1",
            "\(brave):Brave – Work": "3",
        ])
        #expect(
            set.space(app: brave, title: "Inbox - Brave – Work")
                == SpaceID("3")
        )
        #expect(
            set.space(app: brave, title: "Inbox - Brave – Home")
                == SpaceID("1")
        )
    }

    /// The owner's tiebreak: alphabetical, case-folded, so a capital
    /// does not jump the queue as code-point order would make it.
    @Test("equal lengths break alphabetically, case-folded")
    func tieIsAlphabetical() {
        let set = rules([
            "\(brave):Work": "1",
            "\(brave):home": "2",
        ])
        let order = set.order(of: brave).map(\.fragment)
        #expect(order == ["home", "Work"])
        #expect(
            set.space(app: brave, title: "home Work") == SpaceID("2")
        )
        #expect(TitledSpaceRules.precedes("Abc", "abc"))
        #expect(!TitledSpaceRules.precedes("abc", "Abc"))
    }

    @Test("the match is case-sensitive, the app is not")
    func caseSensitiveFragment() {
        let set = rules(["COM.Brave.Browser:Work": "3"])
        #expect(set.space(app: brave, title: "a – Work") == SpaceID("3"))
        #expect(set.space(app: brave, title: "a – work") == nil)
        #expect(set.rawRules == ["\(brave):Work": SpaceID("3")])
    }

    @Test("a key without a fragment is no titled rule")
    func bareKeyIsSkipped() {
        let set = rules([brave: "1", "\(brave):": "2"])
        #expect(!set.hasRule(app: brave))
        #expect(set.rawRules.isEmpty)
    }

    // MARK: - The create fold

    private func window(_ id: UInt32, title: String) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 7,
            appName: "Brave Browser",
            appBundleID: brave,
            title: title,
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

    private func makeState() -> StateCoordinator {
        var state = StateCoordinator(defaultSpace: SpaceID("1"))
        for raw in ["2", "3"] { state.workspaces.ensureSpace(SpaceID(raw)) }
        state.appRules[brave] = SpaceID("2")
        state.titledAppRules = rules(["\(brave):Work": "3"])
        return state
    }

    @Test("a titled rule beats the bare rule at creation")
    func titledBeatsBare() {
        var state = makeState()
        state.apply(.windowCreated(window(1, title: "x - Brave – Work")))
        #expect(state.workspaces.space(of: WindowID(1)) == SpaceID("3"))
    }

    @Test("a title no rule matches takes the bare rule")
    func bareIsTheFallback() {
        var state = makeState()
        state.apply(.windowCreated(window(1, title: "x - Brave – Home")))
        #expect(state.workspaces.space(of: WindowID(1)) == SpaceID("2"))
    }

    @Test("a remembered Space beats a titled rule")
    func memoryBeatsTitled() {
        var state = makeState()
        state.remember(WindowID(1), in: SpaceID("1"))
        state.apply(.windowCreated(window(1, title: "x - Brave – Work")))
        #expect(state.workspaces.space(of: WindowID(1)) == SpaceID("1"))
    }

    @Test("a titled rule earns the launch follow like a bare one")
    func titledRuleFollows() {
        var state = makeState()
        let effects = state.apply(
            .windowCreated(window(1, title: "x - Brave – Work"))
        )
        #expect(effects.placedByAppRule == SpaceID("3"))
    }
}
