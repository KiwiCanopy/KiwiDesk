import Foundation
import Testing

/// KiwiDesk holds `.accessory` for its whole life, and this is
/// what keeps that true.
///
/// The rule used to be promote-on-open / demote-on-close, and the
/// demote had to survive being the *last* of {Settings,
/// onboarding, Config Issues} to close — one rule spread over
/// three controllers, each holding half. `016cc50a` removed the
/// demote from Settings and left the promotion in onboarding,
/// which stranded the app `.regular` with nothing on screen: the
/// active-but-invisible foreground state that breaks
/// `focusedCommandDenial`'s `front == focused.pid` test.
///
/// Deleting the pair removed the *forget* mode — there is no
/// release left to omit. It did not remove the *add* mode:
/// `setActivationPolicy(.regular)` is still one line from any
/// window controller, and nothing about the resulting bug is
/// visible in a diff that adds it. So the exemption list stops
/// being prose here.
///
/// **This map is the one copy of who may set the policy.** Both
/// entries earn it differently, and a third needs the same kind
/// of argument rather than a line in this dictionary:
///
/// - `main.swift` establishes `.accessory` once at launch, which
///   is the rule rather than an exception to it.
/// - `SingleInstanceGuard.swift` raises `.regular` so its
///   already-running alert is not buried behind every other app.
///   Safe by construction rather than by discipline, and the
///   construction is the **`-> Never` return type** on
///   `surfaceRunningInstanceAndExit()`: the compiler will not let
///   that function come back, so no window can outlive the
///   promotion and there is nothing left to demote. A test
///   asserting the same thing was written here and deleted — it
///   restated a compiler guarantee, and no mutation that broke it
///   also compiled, which is the shape `tests.md` names as not
///   owed. If that signature ever loses `Never`, this entry is
///   what stops being true.
///
/// Disclosed limit: `SourceScan.stripComments` cuts each line at
/// its first `//`, even inside a string literal, so a `//`-bearing
/// literal ahead of a needle on the same line erases that hit.
/// Fail-open, and the same limit the sibling seam guards carry.
@Suite("Activation policy seam")
struct ActivationPolicySeamTests {
    private let needles = [
        "setActivationPolicy",
        // The helper that used to wrap the promotion. Banned by
        // name as well as by call, so reintroducing it does not
        // quietly re-open the seam one indirection away.
        "activateAsRegular",
    ]

    /// File path (repo-relative) -> how many times it may name a
    /// policy needle.
    private let allowed = [
        "Sources/KiwiDesk/main.swift": 1,
        "Sources/KiwiDesk/SingleInstanceGuard.swift": 1,
    ]

    @Test("Only launch and the single-instance alert set it")
    func policyStaysWhereItBelongs() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let gui =
            root
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDesk")
        let prefix = root.path + "/"

        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: gui) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = needles.reduce(0) {
                $0 + source.occurrences(of: $1)
            }
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key] = hits
        }

        // Asserted as a whole map rather than per-file, so a NEW
        // file naming the needle fails just as loudly as an
        // existing one gaining a second call.
        #expect(counts == allowed)
    }
}
