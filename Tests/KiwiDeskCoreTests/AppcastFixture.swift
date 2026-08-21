import Foundation
import Testing

/// Fixtures for the `scripts/appcast-sync` suites (#874).
///
/// Shared at the THIRD consumer — `AppcastParserTests`,
/// `AppcastModeTests` and `AppcastNotesTests` — which is where
/// `.claude/rules/parity-tests.md` puts the line. Two copies of
/// a fixture builder is a duplication §2.4 prefers; three is a
/// shape that drifts, and a suite asserting over a release the
/// others no longer produce fails to guard what its name claims.
///
/// A stateless primitive: it builds values and spawns the real
/// script. No setup, no teardown, no assertions of its own.
///
/// **Tags are `v9999.*` deliberately.** The script runs in place
/// and, absent `--notes`, reads the repo's real
/// `site/src/data/changelog.json`; a fixture borrowing a
/// plausible version number would silently start rendering
/// release prose into the output an assertion inspects
/// (`.claude/rules/tests.md` ▸ pin any default a fixture reasons
/// from). No release can ever carry these.
enum AppcastFixture {
    /// A 64-byte Ed25519 signature, base64. Built rather than
    /// pasted, so a change to the length the script expects reds
    /// instead of silently accepting a stale literal.
    static let signature = Data(repeating: 0x41, count: 64)
        .base64EncodedString()

    /// One published release with a notarized archive and its
    /// sidecar — the shape every case is a mutation of.
    static func release(
        tag: String,
        assets: [[String: Any]]? = nil,
        signature: String = AppcastFixture.signature,
        draft: Bool = false
    ) -> [String: Any] {
        let version =
            tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let name = "KiwiDesk-\(version).zip"
        return [
            "tag_name": tag,
            "published_at": "2026-08-26T10:00:00Z",
            "draft": draft,
            "edsig": signature,
            "assets": assets ?? [
                asset(name, tag: tag),
                asset("\(name).edsig", tag: tag, size: 89),
            ],
        ]
    }

    static func asset(
        _ name: String,
        tag: String = "v9999.0.1",
        size: Int = 9_123_456
    ) -> [String: Any] {
        [
            "name": name,
            "size": size,
            "browser_download_url":
                "https://github.com/KiwiCanopy/KiwiDesk/releases"
                + "/download/\(tag)/\(name)",
            "url": "https://api.github.com/assets/9",
        ]
    }

    /// Writes a JSON fixture and hands back its path. The caller
    /// removes it.
    static func write(
        _ object: Any,
        label: String
    ) throws -> URL {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "appcast-\(label)-\(UUID().uuidString).json"
            )
        try JSONSerialization.data(withJSONObject: object)
            .write(to: file)
        return file
    }

    /// A curated-notes file carrying one release's summary —
    /// the shape `scripts/changelog-sync` generates.
    static func notes(
        tag: String,
        summary: String,
        sections: [[String: Any]] = []
    ) -> [String: Any] {
        [
            "generated_by": "AppcastFixture",
            "releases": [
                [
                    "tag": tag,
                    "version": String(tag.dropFirst()),
                    "summary": summary,
                    "sections": sections,
                ]
            ],
        ]
    }

    /// Runs the real script over a fixture, rendering to stdout.
    static func render(
        _ releases: [[String: Any]],
        arguments: [String]
    ) throws -> ScriptRun {
        let file = try write(releases, label: "releases")
        defer { try? FileManager.default.removeItem(at: file) }
        return try runPythonScript(
            at: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts")
                .appendingPathComponent("appcast-sync"),
            arguments: ["--releases", file.path]
                + arguments + ["--output", "-"]
        )
    }
}
