import Foundation
import Testing

/// Phase B may skip its gate only on an exact tree match.
///
/// A release ran the gate five times: phase A locally, CI on the
/// stamp PR, CI again on `main` post-merge, phase B locally, and
/// `release.yml` on the tag. Phase B's bought nothing — the same
/// tree CI had just verified — so it is skipped when phase A
/// recorded a byte-identical tree hash.
///
/// The hash is the whole safety argument. A squash merge of
/// nothing but the stamp reproduces phase A's tree exactly; any
/// other commit landing in between changes it and the gate runs.
/// Skipping on anything weaker — "phase B trusts CI", a version
/// match, a timestamp — would skip on a tree nothing verified.
///
/// **What this suite cannot see.** It reads the script as text,
/// so it holds the *shape* of the decision, not its runtime
/// behaviour: it cannot prove the comparison is reached, and it
/// would not notice the gate being deleted outright.
/// `VerifyGateParityTests` owns what the gate must contain, and
/// `release.yml` re-verifies every tag regardless — which is why
/// a wrongly-skipped phase B costs a red CI run rather than an
/// unverified artifact.
@Suite("Release gate skip")
struct ReleaseGateSkipTests {
    private static func releaseScript() throws -> String {
        try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/release.sh"),
            encoding: .utf8
        )
    }

    /// Non-vacuity: every assertion below is about *how* the skip
    /// is spelled, so an absent skip must red rather than pass.
    @Test("the skip mechanism is present")
    func mechanismIsPresent() throws {
        let script = try Self.releaseScript()
        #expect(
            script.contains("VERIFIED_RECORD"),
            "no verified-tree record — the skip is gone"
        )
        #expect(
            script.contains("GATE_ALREADY_PAID"),
            "no skip flag"
        )
        #expect(
            script.contains("HEAD^{tree}"),
            "the skip is not keyed on a tree hash"
        )
    }

    @Test("the skip requires a non-empty exact match")
    func skipRequiresExactMatch() throws {
        let script = try Self.releaseScript()
        #expect(
            script.contains("[ \"$recorded\" = \"$current\" ]"),
            "the recorded and current trees are not compared"
        )
        #expect(
            script.contains("[ -n \"$recorded\" ]"),
            "an empty record would satisfy the comparison"
        )
    }

    @Test("it fails closed when nothing was verified")
    func failsClosed() throws {
        let script = try Self.releaseScript()
        #expect(
            script.contains("GATE_ALREADY_PAID:-0"),
            "the skip flag does not default to off"
        )
        // A --skip-verify run attests to nothing, so it must not
        // write a record phase B would then honour.
        #expect(
            script.contains(
                """
                    if [ "$SKIP_VERIFY" -eq 0 ]; then
                        git rev-parse "HEAD^{tree}" > "$VERIFIED_RECORD"
                """
            ),
            "the record is written without checking the gate ran"
        )
    }
}
