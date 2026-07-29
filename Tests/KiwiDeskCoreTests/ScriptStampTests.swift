import Foundation
import Testing

/// `scripts/bump-version.sh` really spawned (#32).
///
/// The tag ↔ `KiwiDeskVersion.semantic` mirror cannot be tested
/// here — at `swift test` time the tag does not exist yet, and
/// the only moment both halves exist is inside the release
/// workflow, which is where that guard lives.
///
/// What *is* testable locally is the mechanism underneath it, and
/// it is worth testing because the whole release pipeline trusts
/// it: `sed -i ''` exits 0 when it matches nothing, so a
/// declaration that drifts away from `let <name> = "<value>"`
/// turns the stamp into a silent no-op. The workflow would then
/// build a binary carrying the previous version and Apple-notarize
/// it under the new one — and no step before the download says so.
///
/// So the fixture copies the **real**
/// `Sources/KiwiDeskCore/App/KiwiDeskVersion.swift` rather than a
/// hand-written stand-in. That is the entire point: a test over
/// invented file contents would keep passing on the day someone
/// adds a type annotation to the shipped declaration, which is
/// exactly the change this exists to catch.
///
/// Bash, not `ScriptFixture`'s `runPythonScript` — that harness is
/// python-only, and per `.claude/rules/tests.md` a first copy stays
/// a per-file private helper.
@Suite("Version stamping script")
struct ScriptStampTests {
    // MARK: - The real declaration shape

    @Test("stamps the version and leaves the commit unknown")
    func stampsVersionOnly() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        let run = try fixture.bump(["1.2.3"])

        #expect(run.status == 0, "stderr: \(run.stderr)")
        #expect(try fixture.declaration("semantic") == "1.2.3")
        // Not merely "not the old value": a checked-in tree cannot
        // know the commit it becomes, so "unknown" is the only
        // honest content and the script must reset it.
        #expect(try fixture.declaration("commit") == "unknown")
    }

    @Test("--stamp-commit writes the real HEAD")
    func stampCommitWritesHead() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        let run = try fixture.bump(["1.2.3", "--stamp-commit"])

        #expect(run.status == 0, "stderr: \(run.stderr)")
        #expect(try fixture.declaration("semantic") == "1.2.3")
        let stamped = try fixture.declaration("commit")
        #expect(stamped == fixture.headSHA)
        // Guards the assertion above against passing vacuously if
        // the fixture's git setup ever stops producing a SHA.
        #expect(stamped != "unknown")
        #expect(!(stamped ?? "").isEmpty)
    }

    @Test("re-stamping resets a previously stamped commit")
    func reStampResetsCommit() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        #expect(
            try fixture.bump(["1.2.3", "--stamp-commit"])
                .status == 0
        )
        #expect(try fixture.declaration("commit") != "unknown")

        // A plain bump after a stamped one must not leave the old
        // SHA behind: the tree would then claim a commit it is not.
        #expect(try fixture.bump(["1.2.4"]).status == 0)
        #expect(try fixture.declaration("commit") == "unknown")
    }

    // MARK: - The guard that makes the above trustworthy

    @Test("a drifted declaration fails instead of no-op passing")
    func driftedDeclarationFails() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        // The realistic drift: a type annotation. Equally, wrapping
        // the line for the 79-column limit, or making it computed.
        try fixture.rewriteVersionFile { source in
            source.replacingOccurrences(
                of: "let semantic = ",
                with: "let semantic: String = "
            )
        }

        let run = try fixture.bump(["9.9.9"])

        // `Comment` is ExpressibleByStringLiteral, so the message
        // stays ONE literal — a `+`-concatenation does not convert.
        #expect(
            run.status != 0,
            "an unmatchable declaration must fail, not no-op pass"
        )
        #expect(run.stderr.contains("semantic"))
    }

    // MARK: - What may be released at all

    @Test("a prerelease suffix is refused before anything is cut")
    func prereleaseRefused() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        // CFBundleVersion takes 1-3 integers, so build-app.sh
        // rejects this — but only after `scripts/release.sh` has
        // already PUSHED the tag, and a fetched tag cannot be
        // taken back. The narrower gate has to run first.
        let run = try fixture.bump(["0.9.0-rc1"])

        #expect(run.status != 0)
        // `#require`, not `==` against an optional. Both sides go
        // nil the moment the shipped declaration drifts, and
        // `nil == nil` passes — so this assertion was green under
        // exactly the drift the suite exists to catch. Separate
        // statements: a `try #require` nested inside `#expect`
        // does not expand.
        let want = try #require(original)
        let got = try fixture.declaration("semantic")
        #expect(try #require(got) == want)
    }

    @Test("a two-part version is refused")
    func twoPartRefused() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        #expect(try fixture.bump(["0.9"]).status != 0)
        let want = try #require(original)
        let got = try fixture.declaration("semantic")
        #expect(try #require(got) == want)
    }

    /// The shipped version, read once so the rejection tests can
    /// assert the file was left alone without hard-coding a number
    /// that a real bump would falsify.
    private var original: String? {
        guard
            let source = try? String(
                contentsOf: StampFixture.realVersionFile,
                encoding: .utf8
            )
        else { return nil }
        return StampFixture.declaration("semantic", in: source)
    }
}
