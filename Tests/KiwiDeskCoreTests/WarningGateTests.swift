import Foundation
import Testing

/// `scripts/warning-gate`, the ratchet's second half (#1780):
/// `-warnings-as-errors` cannot promote an isolation a type
/// inherits from an SDK class, so the gate fails on any Swift
/// warning left in the output outside the groups the wrapped
/// command downgrades with `-Wwarning`.
@Suite("Compiler-warning gate (#1780)")
struct WarningGateTests {
    private static let script = scriptFixtureRepoRoot()
        .appendingPathComponent("scripts/warning-gate")

    /// A group no compiler emits, so no clause pins the one the
    /// Build step downgrades today.
    private static let group = "MadeUpGroup"

    /// The flags a ratcheted step passes to downgrade `group`.
    private static let downgrade = [
        "-Xswiftc", "-warnings-as-errors",
        "-Xswiftc", "-Wwarning", "-Xswiftc", group,
    ]

    /// Runs the gate over `log` as the output of a command that
    /// carries `flags`, the way a wrapped `swift build` does.
    private func gate(
        over log: String,
        flags: [String] = downgrade
    ) throws -> ScriptRun {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("warning-gate-\(UUID()).log")
        try log.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = ["/bin/sh", "-c", #"cat "$0""#, url.path]
        return try spawn(
            "/bin/bash",
            [Self.script.path] + command + flags
        )
    }

    private static let isolation = """
        /r/Sources/A.swift:145:26: warning: main actor-isolated \
        static property 'pad' can not be referenced from a \
        nonisolated context
        """

    private static let tagged = """
        /r/Sources/B.swift:253:33: warning: 'x' was \
        deprecated in macOS 14.0 [#\(group)]
        """

    @Test("An unpromoted isolation warning reds the gate")
    func isolationWarningFails() throws {
        let run = try gate(over: "Compiling\n\(Self.isolation)\n")
        #expect(run.status == 1)
        #expect(run.stderr.contains("A.swift:145:26"))
    }

    /// A checkout path with a space still names a `.swift` file.
    @Test("A warning under a spaced path reds the gate")
    func spacedPathFails() throws {
        let log = "/r/My Repo/Sources/A.swift:1:1: warning: x\n"
        #expect(try gate(over: log).status == 1)
    }

    @Test("A downgraded group, a C warning and a clean log pass")
    func exemptionsPass() throws {
        let clang = "/r/Vendor/CLua/src/l.c:9:1: warning: unused"
        for log in [Self.tagged, clang, "Build complete!"] {
            #expect(try gate(over: log + "\n").status == 0, "\(log)")
        }
    }

    /// The exemption is read off the wrapped command's own
    /// flags: without the downgrade the same tag is a warning.
    @Test("A group the command does not downgrade reds the gate")
    func exemptionComesFromTheFlags() throws {
        let log = Self.tagged + "\n"
        #expect(try gate(over: log, flags: []).status == 1)
        let other = ["-Xswiftc", "-Wwarning", "-Xswiftc", "Other"]
        #expect(try gate(over: log, flags: other).status == 1)
        // The tag ends a diagnostic; the same text in a message
        // exempts nothing.
        let quoted = "/r/A.swift:1:1: warning: [#\(Self.group)] x\n"
        #expect(try gate(over: quoted).status == 1)
    }

    /// A terminal run wraps the warning and its group tag in
    /// colour and hyperlink escapes. Both halves: an escaped
    /// warning is still SEEN, and an escaped exemption still
    /// matches.
    @Test("Terminal escapes neither hide a warning nor the tag")
    func escapesAreStripped() throws {
        let paint = "\u{1B}[1;35mwarning: \u{1B}[0m"
        let isolated = "/r/Sources/A.swift:1:1: \(paint)read\n"
        #expect(try gate(over: isolated).status == 1)
        let tag = """
            [#\u{1B}]8;;https://docs.swift.org/x\u{1B}\\\
            \(Self.group)\u{1B}]8;;\u{1B}\\]
            """
        let exempt = "/r/Sources/B.swift:1:1: \(paint)d \(tag)\n"
        #expect(try gate(over: exempt).status == 0)
    }

    @Test("A failing command keeps its own status")
    func commandStatusWins() throws {
        let run = try spawn(
            "/bin/bash",
            [Self.script.path, "/bin/sh", "-c", "exit 3"]
        )
        #expect(run.status == 3)
        #expect(!run.stderr.contains("warning-gate:"))
    }

    /// Every ratcheted step and the skill's local check run
    /// through the gate, or its half of the ratchet is gone.
    @Test("Every ratcheted step runs through the gate")
    func ratchetedStepsAreGated() throws {
        let yaml = try workflowSource("ci.yml")
        for name in ["Build", "Test", "Test (ExecTests)"] {
            let step = try workflowStep(name, in: yaml)
            try #require(
                step.split(separator: "\n").first?
                    .trimmingCharacters(in: .whitespaces)
                    == "- name: \(name)",
                "'\(name)' matched another step"
            )
            #expect(
                step.contains("scripts/warning-gate swift"),
                "ci.yml's \(name) step bypasses the warning gate"
            )
        }
        let skill = try String(
            contentsOf: scriptFixtureRepoRoot().appendingPathComponent(
                ".claude/skills/verify-gate/SKILL.md"
            ),
            encoding: .utf8
        )
        #expect(skill.contains("scripts/warning-gate swift build"))
    }
}
