import Foundation
import Testing

/// **A shell command never appears inside a catalog VALUE**
/// (#1071). It is handed to a translator, and both answers are
/// wrong: translating it yields a command that does not exist,
/// while keeping it verbatim trips `english_residue` — the
/// auditor ran that predicate and `ja`, `ko`, `ru`, `zh-Hans`
/// and `zh-Hant` all flagged `service` and `stop`, so
/// `scripts/merge-keys` would DISCARD the correct translation
/// and `extract-keys --check` would fail the commit.
///
/// So a sentence that must name one interpolates it as an
/// argument, which `_words()` strips before judging residue and
/// which never reaches a catalog at all. That is what
/// `general.login_item.managed_by_service` does, and this is the
/// guard `gui.md` ▸ "a GATED string's audience" cites: without
/// it the specifier can be typed back into the frame and every
/// suite stays green (guard-prover, #1071 finding 2).
///
/// **A sibling gap, stated rather than guarded** (guard-prover,
/// #1071 finding 3): a compound census gate's ARITY is pinned
/// (`ProfilesGateTests`) but the identity of its arms is not, so
/// `.autoStartServiceLoaded` could be swapped for another tag
/// with the suite green. Left unguarded deliberately — the
/// census IS the declaration, so a test naming which tags a row
/// declares would restate it and agree with nothing else
/// (`tests.md` ▸ a drawn VALUE). The greying it drives is
/// behaviour, and `GeneralGateTests` owns that.
///
/// The needle is the INVOCATION shape — the binary name followed
/// by a word — never the product name, which belongs in copy
/// (`PRODUCT_NAMES` requires it verbatim) and appears capitalised
/// in dozens of values.
@Suite("Command literals stay out of the catalog (#1071)")
struct CommandLiteralCatalogTests {
    private func catalog(_ locale: String) throws
        -> [String: String]
    {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
            .appendingPathComponent("\(locale).json")
        let data = try Data(contentsOf: url)
        let raw = try JSONSerialization.jsonObject(with: data)
        return try #require(raw as? [String: String])
    }

    @Test("No catalog value spells a kiwidesk invocation")
    func noInvocationInAnyValue() throws {
        let locales = try FileManager.default
            .contentsOfDirectory(
                atPath: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDeskCore/Resources/Locales"
                    ).path
            )
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
            .sorted()
        // Fail loudly rather than passing on an empty sweep.
        #expect(locales.count >= 10)

        var offenders: [String] = []
        for locale in locales {
            for (key, value) in try catalog(locale) {
                // Lowercase `kiwidesk ` is the CLI binary; the
                // product name is `KiwiDesk` and is welcome.
                guard value.contains("kiwidesk ") else { continue }
                offenders.append("\(locale)/\(key)")
            }
        }
        #expect(
            offenders.isEmpty,
            """
            a shell command is spelled inside these catalog \
            values — interpolate it as an argument instead, so \
            no translator can change it and no residue check \
            can reject it: \(offenders.sorted())
            """
        )
    }
}
