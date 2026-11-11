import Foundation
import Testing

@testable import KiwiDeskCore

/// "Report a problem" (#3214): the bug form opens with the short
/// facts under the form's own field ids, settings never ride in
/// the address, and the exported log opens with those facts and
/// every setting that differs from the built-in defaults.
@Suite("Problem report (#3214)")
struct ProblemReportTests {
    private let report = ProblemReport(
        version: "4.2.1 (abc1234)",
        macOS: "Version 27.2 (Build 26C5)",
        screens: 2,
        separateSpaces: true
    )

    private func query(_ url: URL) -> [String: String] {
        let items =
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems ?? []
        return Dictionary(
            items.map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
    }

    @Test("the form opens the bug template with the facts filled in")
    func formCarriesTheFacts() {
        let url = report.formURL
        #expect(url.host == "github.com")
        #expect(url.path == "/KiwiCanopy/KiwiDesk/issues/new")
        let fields = query(url)
        #expect(fields["template"] == "bug_report.yml")
        #expect(fields["kiwidesk_version"] == "4.2.1 (abc1234)")
        #expect(fields["macos_version"] == "Version 27.2 (Build 26C5)")
        #expect(
            fields["extra_context"]
                == "Screens: 2\nDisplays have separate Spaces: on"
        )
        #expect(fields.count == 4)
    }

    @Test("a plus in a fact survives the form's query")
    func plusIsEscaped() {
        var plus = report
        plus.version = "4.2.1+dev"
        #expect(!plus.formURL.absoluteString.contains("+"))
        #expect(query(plus.formURL)["kiwidesk_version"] == "4.2.1+dev")
    }

    @Test("the log header names the facts, then each changed setting")
    func headerListsChangedSettings() {
        let header = report.logHeader(
            spaceLayouts: ["1 = bsp"],
            changedSettings: ["/settings/gap/global = 4"]
        )
        #expect(
            header == """
                KiwiDesk 4.2.1 (abc1234)
                macOS Version 27.2 (Build 26C5)
                Screens: 2
                Displays have separate Spaces: on
                Space layouts:
                  1 = bsp
                Settings changed from the defaults:
                  /settings/gap/global = 4


                """
        )
        let none = report.logHeader(spaceLayouts: [], changedSettings: [])
        #expect(none.contains("layouts:\n  (none)\nSettings"))
        #expect(none.contains("defaults:\n  (none)\n\n"))
    }

    @Test("changed settings are the differing leaves, by pointer")
    func changedLeavesOnly() {
        let base: JSONValue = .object([
            "gap": .object(["global": .number(10), "inner": .number(10)]),
            "border": .object(["enabled": .bool(true)]),
        ])
        let live: JSONValue = .object([
            "gap": .object(["global": .number(4), "inner": .number(10)]),
            "border": .object(["enabled": .bool(true)]),
            "name": .string("a/b"),
        ])
        let lines = ChangedSettings.lines(
            root: "settings",
            base: base,
            live: live
        )
        #expect(
            lines == [
                "/settings/gap/global = 4",
                "/settings/name = \"a/b\"",
            ]
        )
        #expect(
            ChangedSettings.lines(root: "settings", base: base, live: base)
                .isEmpty
        )
        // A leaf the live document omits still shows, as unset.
        let unset = ChangedSettings.lines(
            root: "settings",
            base: live,
            live: base
        )
        #expect(unset.contains("/settings/name = unset"))
    }

    @Test("default settings report no change")
    func defaultsAreSilent() {
        #expect(
            ChangedSettings.lines(
                root: "settings",
                base: TilingSettings().keepJSON,
                live: TilingSettings().keepJSON
            ).isEmpty
        )
        var changed = TilingSettings()
        changed.gapsGlobal.outer.top += 3
        let lines = ChangedSettings.lines(
            root: "settings",
            base: TilingSettings().keepJSON,
            live: changed.keepJSON
        )
        #expect(lines.count == 1)
        #expect(lines.first?.hasPrefix("/settings/") == true)
    }
}
