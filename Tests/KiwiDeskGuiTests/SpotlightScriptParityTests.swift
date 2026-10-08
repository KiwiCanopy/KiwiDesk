import Foundation
import Testing

@testable import KiwiDesk

/// The spotlight's two halves — `scripts/changelog-sync`, which
/// refuses a release body, and the window, which draws it — read
/// three facts each; every pair is held here by running the script
/// rather than by a literal typed twice (#2038).
@MainActor
@Suite("Spotlight script parity (#2038)")
struct SpotlightScriptParityTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let script = root.appendingPathComponent(
        "scripts/changelog-sync"
    ).path

    private static func python(_ code: String, _ args: [String] = [])
        throws -> String
    {
        let run = try GuiScriptFixture.python(
            [
                "-c",
                "import json, runpy, sys; "
                    + "g = runpy.run_path(sys.argv[1]); " + code,
                script,
            ] + args
        )
        #expect(run.status == 0, "\(run.stderr)")
        return run.stdout
    }

    /// The committed list a row's `{setting:…}` is checked
    /// against at publication is exactly the ids "Show me" can
    /// land on in any build. A new census row that indexes reds
    /// here until its id is added to
    /// `scripts/spotlight-setting-ids.txt`.
    @Test("the landable list is the census's structurally indexed ids")
    func landableListMatches() throws {
        let run = try GuiScriptFixture.python([Self.script, "--census-ids"])
        #expect(run.status == 0, "\(run.stderr)")
        let listed = Set(run.stdout.split(separator: "\n").map(String.init))
        let landable = Set(
            SettingKey.allCases
                .filter(SettingsSearchIndex.structurallyIndexes)
                .map(\.id)
        )
        #expect(
            listed == landable,
            """
            add to scripts/spotlight-setting-ids.txt: \
            \(landable.subtracting(listed).sorted())
            remove: \(listed.subtracting(landable).sorted())
            """
        )
        // A `[space]` instance never lands, whatever the list says.
        #expect(!listed.contains { $0.contains("[space]") })
    }

    @Test("the script's row cap is the window's")
    func rowCapMatches() throws {
        let out = try Self.python("print(g['SPOTLIGHT_MAX_ROWS'])")
        #expect(
            Int(out.trimmingCharacters(in: .whitespacesAndNewlines))
                == UpdateNotesDigest.spotlightCap
        )
    }

    /// One fixture list, both readers: the script judges a patch
    /// by its tag, the window by the feed's version.
    @Test("a patch is a patch to both readers")
    func patchPredicateMatches() throws {
        let cases: [(String, Bool)] = [
            ("2.2.0", false), ("2.2.1", true), ("2.0.10", true),
            ("3.0.0", false), ("2.2.1-rc.1", true), ("2.2.0-rc.2", false),
            ("2.2", false),
        ]
        let out = try Self.python(
            "print(json.dumps([g['is_patch']('v' + v) "
                + "for v in sys.argv[2:]]))",
            cases.map(\.0)
        )
        let script = try #require(
            try JSONSerialization.jsonObject(with: Data(out.utf8))
                as? [Bool]
        )
        #expect(script == cases.map(\.1))
        #expect(
            cases.map { UpdateNotesDigest.isPatch($0.0) } == cases.map(\.1)
        )
    }
}
