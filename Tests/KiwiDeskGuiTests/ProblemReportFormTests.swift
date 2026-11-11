import Foundation
import KiwiDeskCore
import Testing

/// "Report a problem" fills the bug form by field id (#3214), and
/// GitHub drops a query item whose id the form does not declare
/// without a word. So each id the address carries is held to
/// `bug_report.yml`, and the template it names to a file there.
@Suite("Problem report form (#3214)")
struct ProblemReportFormTests {
    @Test("every prefilled field is one the bug form declares")
    func fieldsAreTheForms() throws {
        let templates = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(".github/ISSUE_TEMPLATE")
        let report = ProblemReport(
            version: "1",
            macOS: "2",
            screens: 1,
            separateSpaces: false
        )
        let items = try #require(
            URLComponents(
                url: report.formURL,
                resolvingAgainstBaseURL: false
            )?.queryItems
        )
        let template = try #require(
            items.first { $0.name == "template" }?.value
        )
        let form = try String(
            contentsOf: templates.appendingPathComponent(template),
            encoding: .utf8
        )
        let fields = items.map(\.name).filter { $0 != "template" }
        #expect(fields.count == 3)
        for field in fields {
            #expect(
                form.contains("\n    id: \(field)\n"),
                Comment(rawValue: field)
            )
        }
    }
}
