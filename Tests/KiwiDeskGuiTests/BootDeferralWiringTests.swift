import Foundation
import Testing

/// The span of `defersWindowRuleReconcileToSweep` (#836) — four
/// one-line writes that no behavior suite can reach.
///
/// `start()`, `finishBoot()` and `stop()` are not test-drivable
/// (the first arms the real machine seams, the last tears down a
/// live event loop), and `BootWindowRuleReconcileTests` sets the
/// flag by hand. A guard-prover run on 2026-08-13 deleted all
/// four writes and the whole 3272-test suite stayed green, which
/// is the same shape as the `scheduleStartupSweep()` hole this
/// branch closed one commit earlier.
///
/// What each write is worth, since a needle without the
/// consequence invites its own deletion:
///
/// 1. the raise — without it #836 is simply back;
/// 2. the `start()` early-return lower — a refused boot would
///    otherwise leave the flag up for the session;
/// 3. the `finishBoot` lower, and its POSITION after the sweep's
///    arm — the flag means "no healer is armed yet", so a lower
///    that drifts above `scheduleStartupSweep()` states the
///    opposite of what it is for, and one that leaves
///    `finishBoot` entirely skips every rule reconcile for the
///    rest of the session;
/// 4. the `stop()` lower — a permission revoke mid-scan never
///    reaches the tail, so without this the same session-long
///    skip ships from the other direction.
///
/// Known limits (the #635 practice): these are needles over
/// comment-stripped source, so a write moved behind a condition
/// that never holds still matches. Deletion, and relocation out
/// of the function or across the arm, are what they red on.
@Suite("Boot deferral wiring (#836)")
struct BootDeferralWiringTests {
    private func source(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(path)
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // Fail-shut on the scan itself: an empty read passes
        // every needle below for having found nothing.
        try #require(!text.isEmpty)
        return text
    }

    private var bootPath: String {
        "Sources/KiwiDeskCore/App/KiwiCore+Boot.swift"
    }

    private let flag = "defersWindowRuleReconcileToSweep"

    /// A function's body, matched to its OWN closing brace (a `}`
    /// at declaration indent) rather than to a character budget,
    /// which overshoots into whatever follows.
    private func body(
        of function: String,
        in text: String
    ) throws -> String {
        let pattern =
            "func \(function)\\([\\s\\S]{0,4000}?\\n    \\}"
        return String(
            text[
                try #require(
                    text.range(
                        of: pattern,
                        options: .regularExpression
                    )
                )
            ]
        )
    }

    @Test("start raises the deferral and lowers it if it refuses")
    func startRaisesAndRefusalLowers() throws {
        let start = try body(of: "start", in: try source(bootPath))
        #expect(
            start.contains("\(flag) = true"),
            """
            start() no longer raises the window-rule deferral — \
            the boot's profile reload runs a second full \
            reconcileAll again (#836), unchunked, inside the \
            boot phase.
            """
        )
        #expect(
            start.contains("\(flag) = false"),
            """
            start()'s refusal path no longer lowers the deferral \
            — a boot that never began leaves it raised, and the \
            session skips every window-rule reconcile.
            """
        )
    }

    /// The ORDER is the claim, not the presence: the flag means
    /// "nothing has armed the healing pass yet", so it may only
    /// be lowered once `scheduleStartupSweep()` has run.
    @Test("the tail lowers the deferral after arming the sweep")
    func tailLowersAfterArmingTheSweep() throws {
        let tail = try body(
            of: "finishBoot",
            in: try source(bootPath)
        )
        let arm = try #require(
            tail.range(of: "scheduleStartupSweep()"),
            """
            finishBoot no longer arms the startup sweep — the \
            deferral below has nothing to defer TO.
            """
        )
        let lower = try #require(
            tail.range(of: "\(flag) = false"),
            """
            The boot tail no longer lowers the window-rule \
            deferral — every rule reconcile is skipped for the \
            rest of the session, with every behavior suite green.
            """
        )
        #expect(
            arm.upperBound <= lower.lowerBound,
            """
            The tail lowers the window-rule deferral BEFORE \
            arming the startup sweep. The flag's whole meaning is \
            "no healing pass is armed yet", so this order states \
            the opposite of what the flag is for.
            """
        )
    }

    @Test("stop lowers the deferral too")
    func stopLowersTheDeferral() throws {
        let text = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        #expect(
            try body(of: "stop", in: text)
                .contains("\(flag) = false"),
            """
            stop() no longer lowers the window-rule deferral — a \
            permission revoke mid-scan never reaches the tail, so \
            the rest of the session silently skips every rule \
            reconcile.
            """
        )
    }

    /// The session seam, needled rather than probed on a live
    /// core. `WakeSessionPresenceWiringTests` proves it is not
    /// the inert default, but it cannot see a seam FROZEN at
    /// bootstrap (`let frozen = .live(); … { frozen }`) — proved
    /// green under exactly that mutation — and freezing is the
    /// defect shape the manager's "re-read at fire time, not at
    /// wake" design exists to prevent. Here the closure body is
    /// the assertion.
    @Test("bootstrap wires the session seam to a fresh read")
    func sessionSeamReadsFreshEachCall() throws {
        let text = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
        )
        #expect(
            text.contains("sessionPresence = { .live() }"),
            """
            The session seam is no longer wired to a call of \
            .live() inside the closure. Wired to a value captured \
            once, every replay reports the session as it was at \
            bootstrap — which is never locked, since bootstrap \
            runs before any lock (#835).
            """
        )
    }
}
