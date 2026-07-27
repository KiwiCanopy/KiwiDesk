import Foundation
import Testing

/// Exercises `untranslated_mode_names`: the mirror of the
/// feature-name guard, and deliberately the opposite shape.
///
/// A product name ("App Bar") is a coinage the GUI never
/// translates, so that guard demands the English be **present**. A
/// layout mode name is ordinary tiling vocabulary each locale may
/// render natively, so there is no single right word to demand —
/// this one requires the English name to be **absent** once the
/// locale has translated its own picker. The rule is "prose agrees
/// with your own picker", which needs no opinion about which word
/// is correct, and the locales that keep the English names are
/// skipped by construction rather than by an exemption list.
///
/// Fixtures are text the test writes itself, never the shipped
/// catalogs — asserting against the corpus would make the guard's
/// coverage depend on the corpus staying dirty.
@Suite("extract-keys mode-name guard")
struct LocalizationModeNameGuardTests {
    /// The defect as it shipped: the picker was translated, the
    /// prose beside it was not.
    @Test(
        "keeping the English name after translating the picker",
        arguments: [
            (
                "Flotante", "Floating no tiene anulaciones.",
                "Floating"
            ),
            (
                "Monóculo", "La App Bar de Monocle se configura.",
                "Monocle"
            ),
            (
                "Pista", "Solo si utilizas el diseño Track.",
                "Track"
            ),
        ]
    )
    func keptEnglishNameFails(
        picker: String,
        value: String,
        english: String
    ) throws {
        let result = try ModeNameFixture.check(
            picker: picker,
            value: value,
            english: english
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("mode name"))
    }

    /// A locale that translated the picker AND the prose is the
    /// fixed shape, and must stay silent.
    @Test(
        "translating both picker and prose passes",
        arguments: [
            ("Flotante", "Flotante no tiene anulaciones.", "it"),
            ("浮动", "浮动没有按空间划分的覆盖。", "zh-Hans"),
            ("モノクル", "モノクルに表示されます。", "ja"),
        ]
    )
    func translatedProsePasses(
        picker: String,
        value: String,
        locale: String
    ) throws {
        let result = try ModeNameFixture.check(
            picker: picker,
            value: value,
            locale: locale
        )
        #expect(result.status == 0)
    }

    /// The locales that keep the English mode names — `de`, `ru`,
    /// `zh-Hant` — are skipped because their picker *is* the
    /// English word, so there is nothing to disagree with. This is
    /// what makes the guard need no exemption list; if it ever
    /// starts failing, the skip has been lost and three locales
    /// are being told to stop using their own picker's word.
    @Test("a locale that kept the English picker is untouched")
    func untranslatedPickerIsSkipped() throws {
        let result = try ModeNameFixture.check(
            picker: "Floating",
            value: "Floating hat keine Überschreibungen."
        )
        #expect(result.status == 0)
    }

    /// **Case is the referential/descriptive discriminator**, and
    /// this is the pair that earns it. English itself writes the
    /// mode names lower-case in running prose ("in the bsp, stack,
    /// scrolling, and track layouts") and capitalises only when
    /// naming the picker entry — so matching the capitalised form
    /// alone follows the source's own convention. A locale using
    /// the English word as a borrowed adjective ("la modalità
    /// floating") is describing behaviour, not naming the picker,
    /// and must not be flagged.
    @Test(
        "case separates naming the mode from describing it",
        arguments: [
            ("Fluttuante", "La modalità floating rimuove.", 0),
            ("Fluttuante", "non della disposizione Floating", 1),
        ]
    )
    func lowerCaseIsDescriptive(
        picker: String,
        value: String,
        expected: Int32
    ) throws {
        let result = try ModeNameFixture.check(
            picker: picker,
            value: value
        )
        #expect(result.status == expected)
    }

    /// Whole-word matching, so a mode name embedded in a longer
    /// token is not a hit. Without this the guard would fire on
    /// unrelated vocabulary that merely starts the same way.
    @Test("a longer word containing the name is not a hit")
    func substringIsNotAHit() throws {
        let result = try ModeNameFixture.check(
            picker: "Pila",
            value: "Il valore Stackoverflow non è un nome.",
            english: "Stack"
        )
        #expect(result.status == 0)
    }
}

/// Spawns `extract-keys --check` over a temp tree with one prose
/// key and one `layout.stack.name` picker key.
///
/// `english` is the mode name the English side declares — varied
/// per case so a fixture can exercise Monocle or Track, since the
/// guard reads the name from the English catalog and never from
/// the key's spelling.
///
/// `locale` must match the script the value is written in: the
/// *script* guard runs in the same pass, so a Chinese value filed
/// under `it` fails as foreign and proves nothing about this rule.
/// Mirrors `ProductNameFixture`; shared spawn primitives come from
/// `ScriptFixture`.
private enum ModeNameFixture {
    static func check(
        picker: String,
        value: String,
        english: String = "Floating",
        locale: String = "it"
    ) throws -> ScriptRun {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-mode-name-\(UUID().uuidString)"
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
        try """
        let _ = L("layout.stack.name", "\(english)")
        let _ = L("a.key", "\(english) has no overrides.")
        """
        .write(
            to: sources.appendingPathComponent(
                "Fixture.swift"
            ),
            atomically: true,
            encoding: .utf8
        )
        let script = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/extract-keys")
        var environment = ProcessInfo.processInfo.environment
        environment["KIWIDESK_EXTRACT_SOURCES"] = sources.path
        environment["KIWIDESK_EXTRACT_LOCALES"] = locales.path
        try runPythonScript(
            at: script,
            arguments: [],
            environment: environment
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode([
            "layout.stack.name": picker,
            "a.key": value,
        ]).write(
            to: locales.appendingPathComponent("\(locale).json")
        )
        return try runPythonScript(
            at: script,
            arguments: ["--check"],
            environment: environment
        )
    }
}
