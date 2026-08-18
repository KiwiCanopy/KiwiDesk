import Foundation
import Testing

/// `scripts/release.sh` must never push `main` (#487).
///
/// `main` carries #487's ruleset with `enforce_admins` TRUE, so
/// a direct push is refused and nobody — the owner included —
/// can bypass it. The stamps for 0.9.1, 0.9.5 and 0.9.6 each
/// reached `main` on a branch opened **by hand**, after the
/// script had already failed at its own push: three releases in
/// a row rescuing one failure from memory. The two-phase flow
/// replaced that, and this guard is what keeps a later edit from
/// quietly restoring the push.
///
/// Scanning source for an **absence** is the weak shape
/// `.claude/rules/rule-authoring.md` warns about — a pattern
/// that matches nothing passes for having found no violations
/// rather than for there being none. `inputIsWhatItClaims` is
/// the non-vacuity half: it pins the anchors the scan reads, so
/// a renamed, emptied or restructured script reds here instead
/// of passing silently.
@Suite("Release push seam (#487)")
struct ReleasePushSeamTests {
    private static func releaseScript() throws -> String {
        try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/release.sh"),
            encoding: .utf8
        )
    }

    @Test("the script is the one this suite thinks it is")
    func inputIsWhatItClaims() throws {
        let script = try Self.releaseScript()
        #expect(
            script.contains("git push"),
            "release.sh pushes nothing at all"
        )
        #expect(
            script.contains("chore/stamp-"),
            "no stamp branch — the two-phase flow is gone"
        )
        #expect(
            script.contains("git tag -a"),
            "release.sh no longer creates the tag"
        )
    }

    @Test("no executed command pushes main")
    func neverPushesMain() throws {
        let script = try Self.releaseScript()
        let offenders =
            script
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            .filter { line in
                // Comments and printed instructions are prose,
                // not pushes; only a command counts.
                guard !line.hasPrefix("#"),
                    !line.hasPrefix("echo"),
                    line.contains("git push")
                else { return false }
                return line.contains(" main")
            }

        #expect(
            offenders.isEmpty,
            """
            scripts/release.sh pushes main directly, which \
            #487's protected branch refuses:
            \(offenders.joined(separator: "\n"))
            """
        )
    }
}
