import Foundation
import Testing

/// One damaged worksheet, both scripts, the same verdict.
///
/// `scripts/extract-keys` and `scripts/merge-keys` each decode
/// `missing_<locale>.json` themselves — `read_drafts` and
/// `_load_map` — and each refuses the same three ways of being
/// unreadable: invalid JSON, bytes that are not UTF-8, and a
/// document that is not an object. Two hand-written decoders of
/// one file format is a mirror, and `.claude/rules/parity-tests.md`
/// asks a shipped mirror to carry a forget-proof test.
///
/// The drift is not hypothetical. `read_drafts` was written with
/// `merge-keys._load_map` open beside it and still omitted
/// `UnicodeDecodeError`, so a translator whose editor saved the
/// worksheet as Latin-1 got a refusal from one script and a raw
/// traceback from the other. Each script's own suite stayed
/// green throughout, because each enumerates its own arms and
/// nothing compared them.
///
/// So this suite deliberately asserts the *shared* contract and
/// nothing script-specific: refuse, in the script's own voice,
/// without a traceback, leaving the file untouched. What each
/// script does with a worksheet it CAN read is its own suite's
/// business — `LocaleWorksheetRefusalTests` for the extract
/// side, `MergeKeysContentGuardTests` for the merge side.
@Suite("locale worksheet decode parity")
struct LocaleWorksheetDecodeParityTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    /// A worksheet neither script can read, and why it is one.
    struct Damaged: Sendable, CustomStringConvertible {
        let label: String
        let bytes: [UInt8]
        var description: String { label }

        static func utf8(
            _ label: String,
            _ body: String
        ) -> Damaged {
            Damaged(label: label, bytes: Array(body.utf8))
        }
    }

    /// The three arms, stated once. A fourth way of being
    /// unreadable joins this list and is thereby demanded of
    /// both scripts at once — which is the whole point of the
    /// suite, and why the cases are data rather than functions.
    static let damaged: [Damaged] = [
        .utf8("invalid JSON", #"{ "gap.hint": NOT JSON"#),
        .utf8("not an object", #"["not", "a", "worksheet"]"#),
        Damaged(
            label: "not UTF-8",
            bytes: Array(
                #"{"gap.hint": {"source": "x", "translation": "Größe"}}"#
                    .data(using: .isoLatin1) ?? Data()
            )
        ),
    ]

    @Test(
        "both scripts refuse a worksheet neither can read",
        arguments: damaged,
        ["extract-keys", "merge-keys"]
    )
    func bothScriptsRefuseTheSameDamage(
        _ damaged: Damaged,
        _ script: String
    ) throws {
        #expect(!damaged.bytes.isEmpty, "fixture encoded to nothing")
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-parity",
            locales: [
                // merge-keys verifies every entry against
                // en.json, so it needs one to get as far as
                // opening the worksheet at all.
                "en.json": #"{"gap.hint": "Gap between windows"}"#,
                "de.json": #"{}"#,
            ]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": #"""
            let a = L("gap.hint", "Gap between windows")
            """#
        ])
        try FileManager.default.createDirectory(
            at: fx.worksheets,
            withIntermediateDirectories: true
        )
        let worksheet = fx.worksheets
            .appendingPathComponent("missing_de.json")
        let body = Data(damaged.bytes)
        try body.write(to: worksheet)

        let run = try runRepoScript(
            script,
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )

        #expect(
            run.status != 0,
            "\(script) accepted a \(damaged.label) worksheet"
        )
        // The message is the assertion, not the exit code: a
        // traceback also exits non-zero, and that is exactly how
        // the missing UnicodeDecodeError arm passed for a while.
        #expect(
            !run.stderr.contains("Traceback"),
            "\(script) crashed on a \(damaged.label) worksheet"
        )
        #expect(
            run.stderr.contains(script),
            """
            \(script) failed without naming itself on a \
            \(damaged.label) worksheet: \(run.stderr)
            """
        )
        // Neither script may consume what it could not read.
        #expect(
            try Data(contentsOf: worksheet) == body,
            "\(script) rewrote a \(damaged.label) worksheet"
        )
    }
}
