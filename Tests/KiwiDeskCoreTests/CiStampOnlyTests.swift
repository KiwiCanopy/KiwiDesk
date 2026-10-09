import Foundation
import Testing

/// **CI skips the macOS jobs on a release stamp, and on nothing
/// else** (#2106). `scripts/ci-stamp-only` decides; each test runs
/// it against a throwaway git repository whose one commit pair is
/// the case under test, so the verdict is the script's own and not
/// a reading of its text. A yes may come only from all three
/// clauses together — a stamp branch, the version file alone, one
/// `semantic` literal for another — since every wrong yes skips CI
/// on a real change. The wiring clause holds that `ci.yml` reads the
/// script from the BASE commit, so a PR cannot rewrite its judge.
@Suite("CI skips a stamp-only PR (#2106)")
struct CiStampOnlyTests {
    private static let versionFile =
        "Sources/KiwiDeskCore/App/KiwiDeskVersion.swift"

    /// The version file as the release script stamps it.
    private static func version(
        _ semantic: String,
        commit: String = "unknown"
    ) -> String {
        """
        public enum KiwiDeskVersion {
            public static let semantic = "\(semantic)"

            public static let commit = "\(commit)"
        }

        """
    }

    private static func git(
        _ arguments: [String],
        in repo: URL
    ) throws {
        let run = try spawn(
            "/usr/bin/git",
            [
                "-c", "user.name=t", "-c", "user.email=t@t", "-c",
                "commit.gpgsign=false",
            ] + arguments,
            currentDirectory: repo
        )
        try #require(run.status == 0, "git \(arguments): \(run.stderr)")
    }

    private static func write(
        _ text: String,
        to path: String,
        in repo: URL
    ) throws {
        let url = repo.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// The script's exit status for a repo whose base holds
    /// version 2.2.0 and whose head, on `branch`, holds `files`.
    private static func verdict(
        branch: String,
        files: [String: String]
    ) throws -> Int32 {
        let repo = FileManager.default.temporaryDirectory
            .appendingPathComponent("ci-stamp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: repo) }
        try FileManager.default.createDirectory(
            at: repo,
            withIntermediateDirectories: true
        )
        try git(["init", "-q", "-b", "main"], in: repo)
        try write(version("2.2.0"), to: versionFile, in: repo)
        try write("base\n", to: "other.txt", in: repo)
        try git(["add", "-A"], in: repo)
        try git(["commit", "-q", "-m", "base"], in: repo)
        try git(["checkout", "-q", "-b", branch], in: repo)
        for (path, text) in files {
            try write(text, to: path, in: repo)
        }
        try git(["add", "-A"], in: repo)
        try git(["commit", "-q", "-m", "head"], in: repo)
        let script = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/ci-stamp-only")
        return try spawn(
            "/bin/bash",
            [script.path, branch, "main"],
            currentDirectory: repo
        ).status
    }

    @Test("a stamp alone on its branch skips CI")
    func stampSkips() throws {
        #expect(
            try Self.verdict(
                branch: "chore/stamp-2.3.0",
                files: [Self.versionFile: Self.version("2.3.0")]
            ) == 0
        )
    }

    @Test("the same stamp on another branch runs CI")
    func otherBranchRuns() throws {
        #expect(
            try Self.verdict(
                branch: "fix/version",
                files: [Self.versionFile: Self.version("2.3.0")]
            ) == 1
        )
    }

    @Test("a stamp beside another file runs CI")
    func secondFileRuns() throws {
        #expect(
            try Self.verdict(
                branch: "chore/stamp-2.3.0",
                files: [
                    Self.versionFile: Self.version("2.3.0"),
                    "other.txt": "changed\n",
                ]
            ) == 1
        )
    }

    @Test(
        "any other edit of the version file runs CI",
        arguments: [
            CiStampOnlyTests.version("2.3.0", commit: "abc1234"),
            CiStampOnlyTests.version("2.2.0", commit: "abc1234"),
            CiStampOnlyTests.version("not-a-version"),
            CiStampOnlyTests.version("2.3.0") + "// note\n",
            // A content line spelling a diff header.
            CiStampOnlyTests.version("2.3.0") + "++ injected\n",
            // Every line a version literal, the count wrong: the
            // count check and the numstat check each stop these.
            CiStampOnlyTests.version("2.2.0").replacingOccurrences(
                of: "    public static let semantic = \"2.2.0\"\n",
                with: ""
            ),
            CiStampOnlyTests.version("2.3.0").replacingOccurrences(
                of: "\"2.3.0\"\n",
                with: "\"2.3.0\"\n    public static let semantic = \"2.4.0\"\n"
            ),
        ]
    )
    func otherEditRuns(_ text: String) throws {
        #expect(
            try Self.verdict(
                branch: "chore/stamp-2.3.0",
                files: [Self.versionFile: text]
            ) == 1
        )
    }

    /// Read from the base commit, never the checked-out head, only
    /// for a pull request from this repository (a fork names its
    /// branch freely), and standing without `pipefail`: an empty
    /// read is a no. Its yes, and only its yes, is the step's skip.
    @Test("ci.yml asks the base commit's script")
    func workflowReadsTheBaseScript() throws {
        let step = try workflowStep(
            "Decide whether the build jobs must run",
            in: workflowSource("ci.yml")
        )
        let lines = step.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        for env in [
            "HEAD_REPO: ${{ github.event.pull_request.head.repo.full_name }}",
            "REPO: ${{ github.repository }}",
        ] {
            #expect(lines.contains(env), "missing env \(env)")
        }
        let gate =
            #"if [ "$EVENT" = "pull_request" ] "#
            + #"&& [ "$HEAD_REPO" = "$REPO" ]; then"#
        let read =
            #"stamp_check="$(git show "${base}:scripts/ci-stamp-only" "#
            + #"2>/dev/null || true)""#
        let judge =
            #"if [ -n "$stamp_check" ] "#
            + #"&& bash -c "$stamp_check" ci-stamp-only "#
            + #""$HEAD_REF" "$base"; then"#
        let gateAt = try #require(lines.firstIndex(of: gate))
        #expect(lines[gateAt + 1] == read)
        let judgeAt = try #require(
            lines.firstIndex(of: judge),
            "the changes step does not judge by the base script"
        )
        #expect(judgeAt > gateAt + 1)
        let next = lines[(judgeAt + 1)...].first { !$0.isEmpty }
        #expect(next == #"echo "run=false" >> "$GITHUB_OUTPUT""#)
        #expect(!step.contains("scripts/ci-stamp-only \""))
    }
}
