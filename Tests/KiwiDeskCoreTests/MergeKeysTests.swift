import Foundation
import Testing

/// Exercises `scripts/merge-keys` (issue #252): folding a
/// translated `missing_<locale>.json` worksheet back into
/// `<locale>.json` must merge only entries that are both
/// non-empty *and* still a translation of the current English —
/// a worksheet is filled out over days, and in that window the
/// English meaning can change in code while `drop-key` retires
/// the old translations. Merging on non-emptiness alone silently
/// resurrects the retired meaning, with nothing able to flag it
/// afterwards.
///
/// Harness: the repo-shaped `ScriptFixture` primitives —
/// `merge-keys` derives its locales directory from its own
/// `__file__` and has no env-var override, so the script is
/// copied into a fixture tree.
@Suite("merge-keys")
struct MergeKeysTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    private func fixture(
        locales: [String: String],
        siteLocales: [String: String] = [:]
    ) throws -> RepoShapedFixture {
        try makeRepoShapedFixture(
            prefix: "kiwi-merge-keys",
            locales: locales,
            siteLocales: siteLocales
        )
    }

    @discardableResult
    private func run(
        _ arguments: [String],
        in fixture: RepoShapedFixture
    ) throws -> ScriptRun {
        try runRepoScript(
            "merge-keys",
            arguments: arguments,
            in: fixture,
            repoRoot: repoRoot
        )
    }

    // MARK: - The stale-source guard (the #252 subject)

    @Test("skips an entry whose English changed since extraction")
    func skipsStaleSource() throws {
        let fx = try fixture(locales: [
            // The meaning changed in code after extraction.
            "en.json": #"""
            {"gap.hint": "New meaning", "menu.quit": "Quit"}
            """#,
            "de.json": #"{"menu.quit": "Ende"}"#,
            "missing_de.json": #"""
            {"gap.hint": {"source": "Old meaning",
                          "translation": "Alte Bedeutung"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        // The stale translation must NOT reach the shipped file.
        let de = try fx.decodeLocale("de.json")
        #expect(de["gap.hint"] == nil)
        #expect(de == ["menu.quit": "Ende"])
        #expect(result.stderr.contains("gap.hint"))
        #expect(result.stderr.contains("English changed"))
    }

    @Test("merges an entry whose English is unchanged")
    func mergesMatchingSource() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"gap.hint": "Same meaning"}"#,
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"gap.hint": {"source": "Same meaning",
                          "translation": "Gleiche Bedeutung"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        let de = try fx.decodeLocale("de.json")
        #expect(de == ["gap.hint": "Gleiche Bedeutung"])
    }

    @Test("skips a key that left en.json entirely")
    func skipsKeyRemovedFromEnglish() throws {
        let fx = try fixture(locales: [
            // gone.key was deleted from code since extraction.
            "en.json": #"{"menu.quit": "Quit"}"#,
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"gone.key": {"source": "Vanished",
                          "translation": "Verschwunden"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        let de = try fx.decodeLocale("de.json")
        #expect(de.isEmpty)
        #expect(result.stderr.contains("gone.key"))
    }

    @Test("an entry with no source field is unverifiable, skipped")
    func skipsEntryWithoutSource() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"gap.hint": "Some meaning"}"#,
            "de.json": #"{}"#,
            // A hand-written worksheet gets the same guard as a
            // generated one, not an exemption from it.
            "missing_de.json": #"""
            {"gap.hint": {"translation": "Handgeschrieben"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        #expect(try fx.decodeLocale("de.json").isEmpty)
        #expect(result.stderr.contains("gap.hint"))
    }

    @Test("no source AND no en.json entry is still unverifiable")
    func skipsWhenBothSourceAndEnglishAreAbsent() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"menu.quit": "Quit"}"#,
            "de.json": #"{}"#,
            // The crossed case: neither side has anything to
            // compare. A plain `!=` between the two reads equal
            // and would merge unverifiable text for a key the
            // app no longer ships — the worst combination the
            // guard exists to catch, and the one each of the two
            // single-condition tests above leaves uncovered.
            "missing_de.json": #"""
            {"gone.key": {"translation": "Verschwunden"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        #expect(try fx.decodeLocale("de.json").isEmpty)
        #expect(result.stderr.contains("gone.key"))
    }

    @Test("a null source is unverifiable, not a match")
    func skipsNullSource() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"gap.hint": "Meaning"}"#,
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"gap.hint": {"source": null,
                          "translation": "Bedeutung"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        #expect(try fx.decodeLocale("de.json").isEmpty)
    }

    @Test("a stale key survives to be re-extracted, not lost")
    func staleKeyStaysMissing() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"gap.hint": "New meaning"}"#,
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"gap.hint": {"source": "Old meaning",
                          "translation": "Alte Bedeutung"}}
            """#,
        ])
        defer { fx.cleanup() }

        try run(["de"], in: fx)
        // The worksheet is consumed either way; the key not
        // landing in de.json is what makes extract-keys mint it
        // again, this time carrying the new English.
        #expect(!fx.worksheetExists("missing_de.json"))
        #expect(try fx.decodeLocale("de.json")["gap.hint"] == nil)
    }

    @Test("one stale entry does not block its healthy siblings")
    func staleEntryDoesNotBlockOthers() throws {
        let fx = try fixture(locales: [
            "en.json": #"""
            {"a.key": "New A", "b.key": "B"}
            """#,
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"a.key": {"source": "Old A", "translation": "Alt"},
             "b.key": {"source": "B", "translation": "Be"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        #expect(try fx.decodeLocale("de.json") == ["b.key": "Be"])
    }

    // MARK: - The recovery leg the whole design rests on

    @Test("extract-keys re-mints a skipped key with new English")
    func staleKeyIsReMintedByExtractKeys() throws {
        // The guard is only safe because a skipped key comes
        // BACK. That half lives in `extract-keys`' mint
        // predicate, in a different script — so without this
        // test, tightening that predicate would silently turn
        // merge-keys' skip into permanent loss with a green
        // suite. Both scripts run in one repo-shaped fixture.
        let fx = try fixture(locales: [
            "en.json": #"{"gap.hint": "New meaning"}"#,
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"gap.hint": {"source": "Old meaning",
                          "translation": "Alte Bedeutung"}}
            """#,
        ])
        defer { fx.cleanup() }
        // extract-keys regenerates en.json from real call sites,
        // so the fixture needs the matching source.
        try fx.writeSources([
            "A.swift": #"""
            let a = L("gap.hint", "New meaning")
            """#
        ])

        try run(["de"], in: fx)
        #expect(!fx.worksheetExists("missing_de.json"))

        let extract = try runRepoScript(
            "extract-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(extract.status == 0)

        let worksheet =
            try JSONSerialization.jsonObject(
                with: fx.rawWorksheet("missing_de.json")
            ) as? [String: [String: String]]
        // Back on the to-translate list, carrying the NEW
        // English — not the one the translator worked from.
        #expect(worksheet?["gap.hint"]?["source"] == "New meaning")
        #expect(worksheet?["gap.hint"]?["translation"] == "")
    }
}
