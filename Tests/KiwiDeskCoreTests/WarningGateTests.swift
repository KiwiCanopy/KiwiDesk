import Foundation
import Testing

/// `scripts/warning-gate`, the ratchet's second half (#1780):
/// `-warnings-as-errors` cannot promote an isolation a type
/// inherits from an SDK class, so the gate fails on any Swift
/// warning left in the output outside the exemption.
@Suite("Compiler-warning gate (#1780)")
struct WarningGateTests {
    private static let script = scriptFixtureRepoRoot()
        .appendingPathComponent("scripts/warning-gate")

    /// Runs the gate over `log` as a command's output.
    private func gate(over log: String) throws -> ScriptRun {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("warning-gate-\(UUID()).log")
        try log.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        return try spawn(
            "/bin/bash",
            [Self.script.path, "/bin/cat", url.path]
        )
    }

    private static let isolation = """
        /r/Sources/A.swift:145:26: warning: main actor-isolated \
        static property 'pad' can not be referenced from a \
        nonisolated context
        """

    @Test("An unpromoted isolation warning reds the gate")
    func isolationWarningFails() throws {
        let run = try gate(over: "Compiling\n\(Self.isolation)\n")
        #expect(run.status == 1)
        #expect(run.stderr.contains("A.swift:145:26"))
    }

    @Test("The exempt group, a C warning and a clean log pass")
    func exemptionsPass() throws {
        let deprecated = """
            /r/Sources/B.swift:253:33: warning: 'x' was \
            deprecated in macOS 14.0 [#DeprecatedDeclaration]
            """
        let clang = "/r/Vendor/CLua/src/l.c:9:1: warning: unused"
        for log in [deprecated, clang, "Build complete!"] {
            #expect(try gate(over: log + "\n").status == 0, "\(log)")
        }
    }

    /// A terminal run wraps the group tag in colour and
    /// hyperlink escapes; the exemption must still match.
    @Test("The exemption survives terminal escapes")
    func escapedTagPasses() throws {
        let log = """
            /r/Sources/B.swift:1:1: \u{1B}[1;35mwarning: \
            \u{1B}[0m\u{1B}[1;39md\u{1B}[0;0m [#\u{1B}]8;;\
            https://docs.swift.org/x\u{1B}\\DeprecatedDeclaration\
            \u{1B}]8;;\u{1B}\\]

            """
        #expect(try gate(over: log).status == 0)
    }

    @Test("A failing command keeps its own status")
    func commandStatusWins() throws {
        let run = try spawn("/bin/bash", [Self.script.path, "/usr/bin/false"])
        #expect(run.status == 1)
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

    /// The group the gate lets through is the one the Build step
    /// downgrades: a downgrade retired with #1170 must leave the
    /// gate no exemption either.
    @Test("The gate exempts the Build step's downgraded group")
    func exemptionMatchesTheDowngrade() throws {
        let step = try workflowStep("Build", in: workflowSource("ci.yml"))
        let words = step.split(whereSeparator: \.isWhitespace)
        let downgraded = words.indices.dropLast(2)
            .filter { words[$0] == "-Wwarning" }
            .map { String(words[$0 + 2]) }
        let script = try String(contentsOf: Self.script, encoding: .utf8)
        let exempt = script.split(separator: "\n")
            .filter { $0.contains("grep -vF") }
            .compactMap { $0.split(separator: "'").dropFirst().first }
            .map { String($0.dropFirst(2).dropLast()) }
        #expect(exempt == downgraded)
    }
}
