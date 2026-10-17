import Foundation
import Testing

/// The spotlight's row count and line length are guidelines, not
/// refusals (owner ruling 2026-10-17): `--body` accepts a draft
/// past either and warns. Both numbers are read off the script, so
/// a deliberate retune moves the cases with it.
@Suite("Changelog spotlight guidelines")
struct ChangelogSpotlightGuidelineTests {
    private static let script = scriptFixtureRepoRoot()
        .appendingPathComponent("scripts/changelog-sync")

    private func guideline(_ name: String) throws -> Int {
        let run = try spawn(
            "/usr/bin/env",
            [
                "python3", "-c",
                "import runpy, sys; "
                    + "print(runpy.run_path(sys.argv[1])[sys.argv[2]])",
                Self.script.path, name,
            ]
        )
        return try #require(
            Int(run.stdout.trimmingCharacters(in: .whitespacesAndNewlines)),
            "\(run.stderr)"
        )
    }

    private func check(_ rows: [String]) throws -> ScriptRun {
        let body = """
            ## Highlights

            KiwiDesk 3.0 brings a lot.

            ### Spotlight

            \(rows.joined(separator: "\n"))

            ### New

            - A thing.
            """
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "changelog-guideline-\(UUID().uuidString).md"
            )
        try body.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        return try runPythonScript(
            at: Self.script,
            arguments: ["--body", file.path]
        )
    }

    private func rows(_ count: Int) -> [String] {
        (1...count).map { "- **Row \($0)** — a short line." }
    }

    /// A row whose line is `length` characters, ending in a period.
    private func row(lineLength length: Int) -> String {
        "- **Long** — " + String(repeating: "a", count: length - 1) + "."
    }

    @Test("rows at the guideline pass without a warning")
    func atTheGuideline() throws {
        let rowGuideline = try guideline("SPOTLIGHT_ROW_GUIDELINE")
        let run = try check(rows(rowGuideline))
        #expect(run.status == 0, "\(run.stderr)")
        #expect(!run.stderr.contains("WARNING"))
    }

    @Test("rows past the guideline pass with a warning")
    func pastTheGuideline() throws {
        let past = try guideline("SPOTLIGHT_ROW_GUIDELINE") + 1
        let run = try check(rows(past))
        #expect(run.status == 0, "\(run.stderr)")
        #expect(
            run.stderr.contains("\(past) spotlight rows, past the guideline")
        )
    }

    @Test("a line at the guideline is quiet, one past it warns")
    func lineEdge() throws {
        let limit = try guideline("SPOTLIGHT_LINE_GUIDELINE")
        let at = try check([row(lineLength: limit)])
        #expect(at.status == 0, "\(at.stderr)")
        #expect(!at.stderr.contains("WARNING"))
        let past = try check([row(lineLength: limit + 1)])
        #expect(past.status == 0, "\(past.stderr)")
        #expect(past.stderr.contains("spotlight row \"Long\": its line"))
    }
}
