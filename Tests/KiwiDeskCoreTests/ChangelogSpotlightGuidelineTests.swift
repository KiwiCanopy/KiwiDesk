import Foundation
import Testing

/// The spotlight's row count and line length are guidelines, not
/// refusals (owner ruling 2026-10-17): `--body` accepts a draft
/// past either and warns.
@Suite("Changelog spotlight guidelines")
struct ChangelogSpotlightGuidelineTests {
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
            at: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/changelog-sync"),
            arguments: ["--body", file.path]
        )
    }

    private func rows(_ count: Int) -> [String] {
        (1...count).map { "- **Row \($0)** — a short line." }
    }

    @Test("rows at the guideline pass without a warning")
    func atTheGuideline() throws {
        let run = try check(rows(6))
        #expect(run.status == 0, "\(run.stderr)")
        #expect(!run.stderr.contains("WARNING"))
    }

    @Test("rows past the guideline pass with a warning")
    func pastTheGuideline() throws {
        let run = try check(rows(7))
        #expect(run.status == 0, "\(run.stderr)")
        #expect(run.stderr.contains("7 spotlight rows, past the guideline"))
    }

    @Test("a line that wraps passes with a warning")
    func longLine() throws {
        let line = String(repeating: "word ", count: 16) + "end."
        let run = try check(["- **Long** — \(line)"])
        #expect(run.status == 0, "\(run.stderr)")
        #expect(run.stderr.contains("spotlight row \"Long\": its line"))
    }
}
