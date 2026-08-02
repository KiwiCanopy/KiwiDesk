import Foundation
import Testing

/// Forget-proof parity for the content guards' three registries
/// (issue #95, `.claude/rules/parity-tests.md`).
///
/// `_STUB_TAGS`, `SCRIPTS` and `LATIN_LOCALES` in
/// `scripts/localization_guards.py` are hand-maintained tables
/// keyed by locale, and a locale absent from them loses guards
/// **silently** — `tagged_stub` finds no tag set and returns
/// nothing, `english_residue` reads the locale as Latin-script and
/// returns nothing. Guards off, no signal: the failure those
/// guards exist to prevent, one level up, so it gets a net of its
/// own.
///
/// The script declaration is worse than silent since the
/// feature-name guard arrived. It holds Latin-script locales to
/// keeping "App Bar" verbatim, so a non-Latin locale missing its
/// `SCRIPTS` row is read as Latin and **demanded** to carry an
/// ASCII phrase inside its own script — loudly wrong rather than
/// quietly off. Hence a locale must *declare* its script, and the
/// two sets must be disjoint.
///
/// Unlike the other guard suites this one *does* walk the shipped
/// catalogs — deliberately. The thing under test is the relation
/// "every file we ship is registered", which has no meaning
/// against invented locales. It cannot pass for the wrong reason
/// the way a corpus-derived *content* assertion could: adding a
/// locale file makes it fail until the tables are updated, which
/// is exactly the intended trigger.
@Suite("localization guard registry")
struct LocalizationRegistryTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    private var localesDir: URL {
        repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Locales")
    }

    /// Every shipped `<locale>.json`, the same set
    /// `shipped_locale_files()` walks — including its
    /// `missing_` filter, which is deliberate residue rather
    /// than an assumption that worksheets live here. They do
    /// not (`scripts/locale_paths.py`); the filter keeps this
    /// walker from reporting a stray one as an unregistered
    /// locale before `extract-keys --check` has named it as a
    /// misplaced worksheet.
    private func shippedLocales() throws -> [String] {
        try FileManager.default
            .contentsOfDirectory(atPath: localesDir.path)
            .filter { $0.hasSuffix(".json") }
            .filter { !$0.hasPrefix("missing_") }
            .map { String($0.dropLast(".json".count)) }
            .filter { $0 != "en" }
            .sorted()
    }

    /// Runs `body` against the real module and returns its stdout,
    /// so a test cannot drift from the module's own notion of what
    /// is registered. `json` and `sys.argv` are in scope.
    private func pythonJSON(_ body: String) throws -> String {
        let script = """
            import json, sys
            sys.path.insert(0, sys.argv[1])
            \(body)
            """
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("reg-\(UUID().uuidString).py")
        defer { try? FileManager.default.removeItem(at: file) }
        try script.write(
            to: file,
            atomically: true,
            encoding: .utf8
        )
        let run = try runPythonScript(
            at: file,
            arguments: [
                repoRoot.appendingPathComponent("scripts").path
            ]
        )
        return run.stdout.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    /// Asks the module itself, so the test cannot drift from the
    /// predicate's own notion of "registered".
    private func unregistered(
        _ locales: [String]
    ) throws -> String {
        let script = """
            import json, sys
            sys.path.insert(0, sys.argv[1])
            from localization_guards import unregistered_locales
            print(json.dumps(
                unregistered_locales(json.loads(sys.argv[2]))
            ))
            """
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("reg-\(UUID().uuidString).py")
        defer { try? FileManager.default.removeItem(at: file) }
        try script.write(to: file, atomically: true, encoding: .utf8)
        let payload = String(
            data: try JSONEncoder().encode(locales),
            encoding: .utf8
        )!
        let run = try runPythonScript(
            at: file,
            arguments: [
                repoRoot.appendingPathComponent("scripts").path,
                payload,
            ]
        )
        return run.stdout.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    @Test("every shipped locale is registered")
    func everyShippedLocaleIsRegistered() throws {
        let locales = try shippedLocales()
        // Guards against the net itself rotting into a no-op: a
        // glob that matched nothing would "pass" forever.
        #expect(locales.count >= 10)
        #expect(try unregistered(locales) == "[]")
    }

    /// The net has to fail for an unregistered locale, or the
    /// assertion above proves nothing.
    @Test("an unregistered locale is reported")
    func unregisteredLocaleIsReported() throws {
        let reported = try unregistered(["de", "pl", "hi"])
        #expect(reported.contains("pl"))
        #expect(reported.contains("hi"))
        #expect(!reported.contains("de"))
    }

    /// Which script a locale writes in is a **declaration**, not a
    /// default: a locale must name itself in `LATIN_LOCALES` or in
    /// `SCRIPTS`, even when its stub tags are registered.
    ///
    /// This used to be optional, on the reasoning that absence from
    /// `SCRIPTS` means Latin-script and that is a real answer. The
    /// reasoning holds; relying on it does not, because being wrong
    /// is invisible. `english_residue` keys off
    /// `NON_LATIN_LOCALES`, so a Greek locale with registered tags
    /// but no script row has that guard silently disabled and
    /// reports like a clean catalog. `el` has tags here only
    /// because `_STUB_TAGS` is keyed by base language and `el` is
    /// absent from it too; the point is that the report names it
    /// either way.
    ///
    /// The two script sets must not overlap. There is no
    /// order-dependence to fear — `english_residue` makes one
    /// membership test against `NON_LATIN_LOCALES` and nothing
    /// reads `LATIN_LOCALES` except the union in
    /// `unregistered_locales` — so a locale in both gets a
    /// deterministic answer. The hazard is that the answer is
    /// deterministically *one-sided*: registration passes, residue
    /// runs, and the `LATIN_LOCALES` half is an inert promise the
    /// tooling never consults. A self-contradictory declaration
    /// that reads as satisfied is the state this pair exists to
    /// make impossible.
    @Test("the script declarations are disjoint")
    func scriptSetsAreDisjoint() throws {
        let overlap = try pythonJSON(
            """
            from localization_guards import (
                LATIN_LOCALES, NON_LATIN_LOCALES
            )
            print(json.dumps(
                sorted(LATIN_LOCALES & NON_LATIN_LOCALES)
            ))
            """
        )
        #expect(overlap == "[]")
        // And neither is empty, or the intersection above is
        // vacuously clean.
        for name in ["LATIN_LOCALES", "NON_LATIN_LOCALES"] {
            let members = try pythonJSON(
                """
                from localization_guards import \(name)
                print(json.dumps(sorted(\(name))))
                """
            )
            #expect(members != "[]", "\(name) is empty")
        }
    }

    @Test("a locale with no script declaration is reported")
    func undeclaredScriptIsReported() throws {
        // `de` IS declared (Latin) and `ja` IS declared (via
        // SCRIPTS), so neither may appear — otherwise this would
        // pass by flagging everything.
        let reported = try unregistered(["de", "ja", "el"])
        #expect(reported.contains("el"))
        #expect(!reported.contains("de"))
        #expect(!reported.contains("ja"))
    }

    /// A non-Latin locale must also be in `SCRIPTS`, or its own
    /// script reads as foreign to it — the fail-closed twin of the
    /// silent gap above. Every shipped non-Latin locale must
    /// therefore accept text in its own script.
    @Test(
        "a non-Latin locale accepts its own script",
        arguments: [
            ("ru", "Фокус"), ("ja", "フォーカス"),
            ("ko", "포커스"), ("zh-Hans", "焦点"),
            ("zh-Hant", "焦點"),
        ]
    )
    func nonLatinLocaleAcceptsOwnScript(
        locale: String,
        sample: String
    ) throws {
        let script = """
            import sys
            sys.path.insert(0, sys.argv[1])
            from localization_guards import foreign_scripts
            print(foreign_scripts(sys.argv[2], sys.argv[3]))
            """
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("scr-\(UUID().uuidString).py")
        defer { try? FileManager.default.removeItem(at: file) }
        try script.write(to: file, atomically: true, encoding: .utf8)
        let run = try runPythonScript(
            at: file,
            arguments: [
                repoRoot.appendingPathComponent("scripts").path,
                locale,
                sample,
            ]
        )
        #expect(
            run.stdout.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) == "[]"
        )
    }
}
