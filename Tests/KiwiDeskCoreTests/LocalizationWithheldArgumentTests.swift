import Foundation
import Testing

/// Exercises `withheld_argument_position` (#753): a frame that
/// interpolates an argument the app may render as `""` has to put
/// that specifier last.
///
/// The other specifier guard, `placeholder_drift`, compares the
/// set and deliberately ignores order — the numbering exists so a
/// translation *can* move them, and `TRANSLATION_BRIEF.md` rule 2
/// says so. This is the one exception, and it is invisible from
/// the catalog: only the calling code knows the clause can be
/// absent, so the exception is a register (`WITHHELD_ARGUMENTS`)
/// rather than a shape a scanner could infer.
///
/// Failing looks like nothing at runtime, which is why it earns a
/// guard rather than a paragraph: the sentence renders with a
/// doubled space and a gap where the clause was, in a language
/// nobody reviewing the change reads.
///
/// The fixture writes both sides itself, and the *keys* it writes
/// are the real registered ones — that is what puts the shipped
/// register under test rather than a stand-in. No shipped catalog
/// value is read.
@Suite("extract-keys withheld-argument guard")
struct LocalizationWithheldArgumentTests {
    /// Both registered keys, each with the specifier its own
    /// frame withholds. Listed rather than read from the script,
    /// so a key quietly dropped from `WITHHELD_ARGUMENTS` leaves
    /// this red instead of vacuously green.
    @Test(
        "a mid-sentence withheld argument fails",
        arguments: [
            ("layout.schematic.scrolling.caption_anchored", "%1$@"),
            ("layout.schematic.scrolling.caption_follow", "%2$@"),
        ]
    )
    func midSentenceFails(key: String, spec: String) throws {
        // English stays well-formed, so the only thing under test
        // is the translator's half.
        let result = try WithheldFixture.check(
            key: key,
            english: "A start. \(spec)",
            value: "Ein Anfang. \(spec) Ein Ende."
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains(spec))
        #expect(result.stderr.contains(key))
    }

    /// Trailing is the whole point, and terminal punctuation may
    /// still follow — a locale that closes the sentence after the
    /// clause is fine, since an empty render takes the space with
    /// it and leaves the period where it was.
    @Test(
        "a trailing withheld argument passes",
        arguments: ["Ein Satz. %2$@", "Ein Satz. %2$@。", "%2$@"]
    )
    func trailingPasses(value: String) throws {
        let result = try WithheldFixture.check(
            key: "layout.schematic.scrolling.caption_follow",
            english: "A sentence. %2$@",
            value: value
        )
        #expect(result.status == 0)
    }

    /// And the rule is scoped to the register: every other key in
    /// the app may move its specifiers wherever the sentence needs
    /// them, which is what the numbering is for. A guard that
    /// leaked past the register would fail 113 correct values in
    /// the shipped corpus.
    @Test("an unregistered key may lead with its specifier")
    func unregisteredKeyIsFree() throws {
        let result = try WithheldFixture.check(
            key: "a.open",
            english: "Open %1$@",
            value: "%1$@ öffnen"
        )
        #expect(result.status == 0)
    }

    /// A dropped specifier is `placeholder_drift`'s to report, so
    /// this predicate stays silent on it — one defect, one name.
    @Test("a dropped specifier is not reported twice")
    func droppedIsDriftAlone() throws {
        let result = try WithheldFixture.check(
            key: "layout.schematic.scrolling.caption_follow",
            english: "A sentence. %2$@",
            value: "Ein Satz."
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("drops"))
        #expect(!result.stderr.contains("mid-sentence"))
    }
}

/// Spawns `extract-keys --check` over a one-key temp tree, under
/// the caller's own key so the shipped register decides the
/// verdict. Mirrors `ProductNameFixture`; the shared script-spawn
/// primitives come from `ScriptFixture`.
private enum WithheldFixture {
    static func check(
        key: String,
        english: String,
        value: String
    ) throws -> ScriptRun {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-withheld-\(UUID().uuidString)"
            )
        let sources = base.appendingPathComponent("Sources")
        let locales = base.appendingPathComponent("Locales")
        defer { try? FileManager.default.removeItem(at: base) }
        for directory in [sources, locales] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        let escaped =
            english
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        try "let _ = L(\"\(key)\", \"\(escaped)\")".write(
            to: sources.appendingPathComponent("Fixture.swift"),
            atomically: true,
            encoding: .utf8
        )
        let script = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/extract-keys")
        var environment = ProcessInfo.processInfo.environment
        environment["KIWIDESK_EXTRACT_SOURCES"] = sources.path
        environment["KIWIDESK_EXTRACT_LOCALES"] = locales.path
        // Generate `en.json` first, so `--check` has an English
        // side to compare the locale value against.
        try runPythonScript(
            at: script,
            arguments: [],
            environment: environment
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode([key: value]).write(
            to: locales.appendingPathComponent("de.json")
        )
        return try runPythonScript(
            at: script,
            arguments: ["--check"],
            environment: environment
        )
    }
}
