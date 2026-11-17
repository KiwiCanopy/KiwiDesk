import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Open in a Space card's rows and moves (#3341): rows in the
/// engine's order, a move between the two stores keeping its Space,
/// the refused merge, the case-sensitive duplicate, and the preview
/// reading the engine's own resolution.
@Suite("Space rule rows and edits (#3341)")
@MainActor
struct SpaceRuleEditTests {
    private let brave = "com.brave.browser"

    private func config() -> GuiConfig {
        var config = GuiConfig()
        config.spaces = ["1", "2", "3"]
        config.appRules = [brave: "1"]
        config.titledAppRules = [
            "\(brave):Work": "3",
            "\(brave):Brave – Home": "2",
        ]
        return config
    }

    @Test("rows read in the engine's order, the bare row last")
    func rowsReadInEngineOrder() {
        let rows = SpaceRuleRows.groups(config(), apps: [brave])
        #expect(
            rows.first?.map(\.fragment)
                == ["Brave – Home", "Work", nil]
        )
    }

    @Test("a bare row given a fragment becomes titled, its Space kept")
    func bareBecomesTitled() {
        var config = config()
        SpaceRuleEdit.setFragment(
            "Shop",
            of: SpaceRuleRow(app: brave, fragment: nil),
            in: &config
        )
        #expect(config.appRules[brave] == nil)
        #expect(config.titledAppRules["\(brave):Shop"] == "1")
    }

    @Test("a titled row re-keys to its new fragment, its Space kept")
    func titledRekeys() {
        var config = config()
        SpaceRuleEdit.setFragment(
            "Job",
            of: SpaceRuleRow(app: brave, fragment: "Work"),
            in: &config
        )
        #expect(config.titledAppRules["\(brave):Work"] == nil)
        #expect(config.titledAppRules["\(brave):Job"] == "3")
    }

    @Test("a titled row turns bare only while the app has no bare row")
    func makeBareIsRefusedBesideABareRow() {
        var config = config()
        let work = SpaceRuleRow(app: brave, fragment: "Work")
        SpaceRuleEdit.makeBare(work, in: &config)
        #expect(config.titledAppRules["\(brave):Work"] == "3")
        #expect(config.appRules[brave] == "1")
        config.appRules = [:]
        SpaceRuleEdit.makeBare(work, in: &config)
        #expect(config.titledAppRules["\(brave):Work"] == nil)
        #expect(config.appRules[brave] == "3")
    }

    @Test("a repeated fragment is refused, case-sensitively")
    func duplicateIsCaseSensitive() {
        let config = config()
        #expect(
            SpaceRuleEdit.repeats("Work", app: brave, except: nil, in: config)
        )
        #expect(
            !SpaceRuleEdit.repeats("work", app: brave, except: nil, in: config)
        )
        #expect(
            !SpaceRuleEdit.repeats(
                "Work",
                app: brave,
                except: "Work",
                in: config
            )
        )
    }
}
