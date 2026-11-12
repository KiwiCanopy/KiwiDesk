import Foundation
import Testing

@testable import KiwiDeskCore

/// The committed docs index is what `scripts/docs-index` writes
/// from `docs/` (#3213): a docs edit without a regenerate reds
/// here, with the command that fixes it. The index is also held
/// to the anchors `docs/commands.md` links, which a second
/// slugger wrote.
@Suite("docs index drift (#3213)")
struct DocsIndexDriftTests {
    private static var root: URL { scriptFixtureRepoRoot() }

    private static func sections(
        of page: String
    ) throws -> [[String: Any]] {
        let url = root.appendingPathComponent(
            "Sources/KiwiDesk/Resources/DocsIndex.json"
        )
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        let pages = try #require(object["pages"] as? [[String: Any]])
        let found = try #require(
            pages.first { $0["page"] as? String == page }
        )
        return try #require(found["sections"] as? [[String: Any]])
    }

    @Test("the committed index is the script's output")
    func indexMatchesTheDocs() throws {
        let run = try runPythonScript(
            at: Self.root.appendingPathComponent("scripts/docs-index"),
            arguments: ["--check"]
        )
        #expect(
            run.status == 0,
            "the docs index is stale; run: scripts/docs-index"
        )
    }

    @Test("the release sweep leaves the index as it is")
    func sweepChangesNothing() throws {
        let copy =
            testTemporaryDirectory
            .appendingPathComponent("docs-sweep-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: copy) }
        try FileManager.default.copyItem(
            at: Self.root.appendingPathComponent("docs"),
            to: copy
        )
        let scripts = Self.root.appendingPathComponent("scripts")
        let sweep = try runPythonScript(
            at: scripts.appendingPathComponent("unreleased-strip"),
            arguments: ["--docs", copy.path]
        )
        #expect(sweep.status == 0, "\(sweep.stderr)")
        let run = try runPythonScript(
            at: scripts.appendingPathComponent("docs-index"),
            arguments: ["--check", "--docs", copy.path]
        )
        #expect(run.status == 0, "\(run.stderr)")
    }

    @Test("its anchors are the ones the actions page links")
    func anchorsMatchTheActionsPage() throws {
        let reference = try String(
            contentsOf: Self.root
                .appendingPathComponent("docs/lua-reference.md"),
            encoding: .utf8
        )
        let linked = ActionsPage.headingAnchors(in: reference)
        #expect(linked.count > 100)
        var indexed: [String: String] = [:]
        for section in try Self.sections(of: "lua-reference") {
            guard let level = section["level"] as? Int, level >= 3,
                let heading = section["heading"] as? String,
                let anchor = section["anchor"] as? String
            else { continue }
            for name in APIReference.commandNames(inHeading: heading)
            where indexed[name] == nil {
                indexed[name] = anchor
            }
        }
        #expect(indexed == linked)
    }

    @Test("only user-facing pages are indexed")
    func contributorPagesStayOut() throws {
        let url = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Resources/DocsIndex.json"
        )
        let text = try String(contentsOf: url, encoding: .utf8)
        for page in [
            "design-decisions", "architecture", "ui-patterns",
            "translating", "localization-naming", "performance",
        ] {
            #expect(!text.contains("{\"page\": \"\(page)\""), "\(page)")
        }
        #expect(text.contains("{\"page\": \"lua-reference\""))
        // No marker fence outside a code example reaches the app.
        for section in try Self.sections(of: "cli") {
            for part in section["parts"] as? [String] ?? [] {
                #expect(!part.hasPrefix(":::unreleased"))
                #expect(!part.contains("\n:::unreleased\n"))
            }
        }
    }
}
