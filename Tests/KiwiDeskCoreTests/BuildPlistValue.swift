import Foundation

/// One `Info.plist` value from `scripts/build-app.sh`, read
/// through `scripts/read-plist-key`.
///
/// It SPAWNS the script rather than re-implementing the parse,
/// and that is the point. `scripts/build-app.sh` is the one
/// owner of what every shipped bundle declares, and this was
/// about to be the fourth reader of it with its own regex —
/// beside `appcast-sync`, `check-site-tokens.py` and two shell
/// steps in `release.yml`. `.claude/rules/parity-tests.md` puts
/// the line at two mirrors, so the parse lives in one place and
/// everything routes to it.
///
/// The side benefit is that these suites then exercise the real
/// reader: a change that breaks `read-plist-key` reds here as
/// well as in the workflow that depends on it, rather than
/// leaving a Swift copy quietly agreeing with the old shape.
///
/// Returns nil when the key is absent, so a caller can record a
/// specific failure instead of asserting against "".
func buildAppPlistValue(_ key: String) throws -> String? {
    let run = try runPythonScript(
        at: scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("read-plist-key"),
        arguments: [key]
    )
    guard run.status == 0 else { return nil }
    let value = run.stdout.trimmingCharacters(
        in: .whitespacesAndNewlines
    )
    return value.isEmpty ? nil : value
}
