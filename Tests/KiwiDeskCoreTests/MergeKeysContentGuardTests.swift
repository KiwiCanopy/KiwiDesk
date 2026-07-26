import Foundation
import Testing

/// `scripts/merge-keys` runs the same content predicates
/// `extract-keys --check` gates on, per worksheet entry, so a bad
/// translation never reaches a committed catalog (issue #95).
///
/// This is the half `LocalizationContentGuardTests` cannot cover:
/// that suite proves the *gate* rejects contamination, this one
/// proves the *merge* refuses to write it in the first place — and
/// that a clean entry alongside it still lands, so one bad row
/// does not cost a translator the whole worksheet.
@Suite("merge-keys content guards")
struct MergeKeysContentGuardTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    private func fixture(
        _ worksheet: String
    ) throws -> RepoShapedFixture {
        try makeRepoShapedFixture(
            prefix: "kiwi-merge-content",
            locales: [
                "en.json": """
                {
                  "a.good": "Save copy",
                  "a.script": "Focus here",
                  "a.stub": "Icon & name",
                  "a.residue": "Add Window"
                }
                """,
                "ja.json": "{\n  \"a.kept\": \"既存\"\n}",
                "missing_ja.json": worksheet,
            ]
        )
    }

    @Test("a clean entry merges, broken ones are skipped")
    func brokenEntriesAreSkipped() throws {
        let fixture = try self.fixture(
            """
            {
              "a.good": {
                "source": "Save copy",
                "translation": "コピーを保存"
              },
              "a.script": {
                "source": "Focus here",
                "translation": "Фокус здесь"
              },
              "a.stub": {
                "source": "Icon & name",
                "translation": "Icon & name（JA）"
              },
              "a.residue": {
                "source": "Add Window",
                "translation": "追加 Window"
              }
            }
            """
        )
        defer { fixture.cleanup() }
        let run = try runRepoScript(
            "merge-keys",
            arguments: ["ja"],
            in: fixture,
            repoRoot: repoRoot
        )
        #expect(run.status == 0)

        let merged = try fixture.decodeLocale("ja.json")
        #expect(merged["a.good"] == "コピーを保存")
        #expect(merged["a.kept"] == "既存")
        #expect(merged["a.script"] == nil)
        #expect(merged["a.stub"] == nil)
        #expect(merged["a.residue"] == nil)

        // The worksheet is unlinked either way, so the transcript
        // is the only copy of the discarded text left.
        #expect(run.stderr.contains("Cyrillic"))
        #expect(run.stderr.contains("tagged (JA)"))
        #expect(run.stderr.contains("English word(s) Window"))
        #expect(run.stderr.contains("Фокус здесь"))
        #expect(run.stdout.contains("3 dropped"))
    }

    /// The skipped keys are absent from `ja.json` by construction,
    /// which is the precondition `write_missing`'s re-mint recovery
    /// needs — so a translator really can get them back.
    @Test("skipped keys re-surface on the next extract")
    func skippedKeysReSurface() throws {
        let fixture = try self.fixture(
            """
            {
              "a.residue": {
                "source": "Add Window",
                "translation": "追加 Window"
              }
            }
            """
        )
        defer { fixture.cleanup() }
        try fixture.writeSources([
            "Fixture.swift": """
            let _ = L("a.residue", "Add Window")
            """
        ])
        try runRepoScript(
            "merge-keys",
            arguments: ["ja"],
            in: fixture,
            repoRoot: repoRoot
        )
        try runRepoScript(
            "extract-keys",
            arguments: ["ja"],
            in: fixture,
            repoRoot: repoRoot
        )
        #expect(fixture.localeFileExists("missing_ja.json"))
        let worksheet = try fixture.rawLocaleFile(
            "missing_ja.json"
        )
        let text = String(decoding: worksheet, as: UTF8.self)
        #expect(text.contains("a.residue"))
    }
}
