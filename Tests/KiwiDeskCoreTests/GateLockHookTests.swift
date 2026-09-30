import Foundation
import Testing

/// `scripts/gate-hook` queues every heavy verify-gate step behind
/// `scripts/gate-lock`, so parallel sessions stop throttling the
/// machine. The heavy steps are DERIVED from the verify-gate
/// skill — a new `swift …` step the hook's pattern misses would
/// run unqueued and nothing else would notice.
@Suite("Gate hook queues the skill's heavy steps")
struct GateLockHookTests {
    @Test("every `swift` skill step is wrapped whole")
    func heavySkillStepsAreQueued() throws {
        let steps = try VerifyGateParityTests().skillSteps()
            .filter { $0.hasPrefix("swift ") }
        #expect(steps.count >= 3, "scraped too few swift steps")
        for step in steps {
            for command in [step, "cd Sources && \(step) | tail"] {
                let wrapped = try #require(
                    try rewrite(command),
                    "gate-hook let `\(command)` run unqueued"
                )
                #expect(
                    wrapped.hasSuffix(
                        "gate-lock bash -c '\(command)'"
                    )
                )
            }
        }
    }

    @Test("a queued command is never queued twice")
    func alreadyLockedPassesThrough() throws {
        #expect(try rewrite("scripts/gate-lock swift test") == nil)
    }

    @Test("a heavy step inside a quoted argument is not one")
    func quotedMentionPassesThrough() throws {
        #expect(try rewrite("grep -n \"swift test\" x") == nil)
    }

    /// Permission rules judge the REWRITTEN command, so the hook
    /// approves a plain step itself — and nothing a shell could
    /// chain, expand or redirect, which a text rule on the wrapped
    /// `bash -c '…'` could not tell apart.
    @Test("a plain skill step is approved, never a compound one")
    func onlyPlainStepsAreApproved() throws {
        let steps = try VerifyGateParityTests().skillSteps()
            .filter { $0.hasPrefix("swift ") }
        #expect(steps.count >= 3, "scraped too few swift steps")
        for step in steps {
            #expect(try decision(step) == "allow", "\(step)")
        }
        for command in [
            "swift test; rm x", "cd x && swift test",
            "swift test | tail", "swift test > out",
            "swift test --filter 'A|B'", "swift test $(evil)",
            "FOO=1 swift build", "./scripts/release.sh 1.0",
        ] {
            #expect(try rewrite(command) != nil, "\(command)")
            #expect(try decision(command) == nil, "\(command)")
        }
    }

    /// The rewritten command, or nil when the hook passes the
    /// call through. The rest of the tool input must survive.
    private func rewrite(_ command: String) throws -> String? {
        guard let specific = try hookOutput(command) else {
            return nil
        }
        let updated = try #require(
            specific["updatedInput"] as? [String: Any]
        )
        #expect(updated["timeout"] as? Int == 600_000)
        #expect(updated["run_in_background"] as? Bool == true)
        return updated["command"] as? String
    }

    /// The hook's own permission verdict, nil when it leaves the
    /// normal check to judge.
    private func decision(_ command: String) throws -> String? {
        try hookOutput(command)?["permissionDecision"] as? String
    }

    private func hookOutput(
        _ command: String
    ) throws -> [String: Any]? {
        let event: [String: Any] = [
            "tool_name": "Bash",
            "tool_input": [
                "command": command, "timeout": 600_000,
                "run_in_background": true,
            ],
        ]
        let input = FileManager.default.temporaryDirectory
            .appendingPathComponent("gate-hook-\(UUID()).json")
        try JSONSerialization.data(withJSONObject: event)
            .write(to: input)
        defer { try? FileManager.default.removeItem(at: input) }
        let hook = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/gate-hook")
        let run = try spawn(
            "/bin/sh",
            [
                "-c", "exec python3 \"$0\" < \"$1\"", hook.path,
                input.path,
            ]
        )
        #expect(run.status == 0, "\(run.stderr)")
        guard !run.stdout.isEmpty else { return nil }
        let output = try #require(
            try JSONSerialization.jsonObject(
                with: Data(run.stdout.utf8)
            ) as? [String: Any]
        )
        return try #require(
            output["hookSpecificOutput"] as? [String: Any]
        )
    }
}
