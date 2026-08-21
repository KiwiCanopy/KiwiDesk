import Foundation
import Testing

/// The notes half of `scripts/appcast-sync` (#874): the update
/// window renders the text the changelog page renders, so
/// neither surface owns a second copy of a release's prose.
///
/// Split from `AppcastModeTests` because these assert on
/// RENDERED output while that suite asserts on exit status, and
/// together they crossed the file-size ceiling
/// (`.claude/rules/tests.md` ▸ split suites early).
///
/// Every case supplies its own notes through `--notes`. Reading
/// the repo's real `site/src/data/changelog.json` was wrong
/// twice over: it is an input the fixture does not pin, and
/// `site/**` is on `.github/ci-ignore.txt`, so a suite reading
/// it is one CI skips for exactly the edits that change it —
/// `CiPathFilterTests` refuses that outright.
@Suite("Appcast release notes (#874)")
struct AppcastNotesTests {
    private static let tag = AppcastModeTests.goodTag

    /// Driven through `--check`, which runs the strict pass and
    /// NOTHING else. That is what makes the read observable: on
    /// any other path `run_all` re-reads the notes and renders
    /// the feed, so a strict pass that ignored `--notes`
    /// produced identical output and the bug was invisible. With
    /// `--check` the only reader is the one under test, and a
    /// notes file it cannot parse must therefore fail.
    @Test("--release --check reads the notes it was given")
    func strictPathHonoursNotes() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "appcast-bad-notes-\(UUID().uuidString).json"
            )
        try "{ this is not json".write(
            to: file,
            atomically: true,
            encoding: .utf8
        )
        defer { try? FileManager.default.removeItem(at: file) }
        let run = try AppcastFixture.render(
            [AppcastFixture.release(tag: Self.tag)],
            arguments: [
                "--release", Self.tag, "--check",
                "--notes", file.path,
            ]
        )
        #expect(
            run.status != 0,
            "the strict pass must read the file it was handed"
        )
        #expect(run.stderr.contains("not readable"))
    }

    @Test("--release honours the notes override too")
    func strictPathRendersOverriddenNotes() throws {
        let marker = "MARKER-ONLY-IN-THE-FIXTURE"
        let notes: [String: Any] = [
            "generated_by": "AppcastModeTests",
            "releases": [
                [
                    "tag": Self.tag,
                    "version": "9999.1.0",
                    "summary": marker,
                    "sections": [],
                ]
            ],
        ]
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "appcast-strict-notes-\(UUID().uuidString).json"
            )
        try JSONSerialization.data(withJSONObject: notes)
            .write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let run = try AppcastFixture.render(
            [AppcastFixture.release(tag: Self.tag)],
            arguments: [
                "--release", Self.tag, "--notes", file.path,
            ]
        )
        #expect(run.status == 0)
        #expect(run.stdout.contains(marker))
    }

    /// The inline subset must agree with the site's renderer on
    /// the case that CORRUPTS rather than degrades.
    ///
    /// Without a flanking constraint, `*` used as multiplication
    /// opened an emphasis span that closed at the start of the
    /// real one: `2 * 3 = 6 and *why* not` became
    /// `2 <em> 3 = 6 and </em>why* not` here while the changelog
    /// page rendered it correctly. One corpus, two surfaces —
    /// so a divergence is a defect in one of them.
    @Test("emphasis does not run away from a stray asterisk")
    func emphasisRespectsFlanking() throws {
        let notes: [String: Any] = [
            "generated_by": "AppcastModeTests",
            "releases": [
                [
                    "tag": Self.tag,
                    "version": "9999.1.0",
                    "summary": "2 * 3 = 6 and *why* not",
                    "sections": [],
                ]
            ],
        ]
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "appcast-flank-\(UUID().uuidString).json"
            )
        try JSONSerialization.data(withJSONObject: notes)
            .write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let run = try AppcastFixture.render(
            [AppcastFixture.release(tag: Self.tag)],
            arguments: ["--all", "--notes", file.path]
        )
        #expect(
            run.stdout.contains("2 * 3 = 6 and <em>why</em> not"),
            "must match what marked.parseInline renders"
        )
        #expect(!run.stdout.contains("<em> 3 = 6"))
    }

    /// With no curated entry the item still ships, carrying a
    /// thin description. An item with poor prose updates; no
    /// item at all does not.
    @Test("a release with no notes is still offered")
    func missingNotesStillOffers() throws {
        let run = try AppcastFixture.render(
            [AppcastFixture.release(tag: Self.tag)],
            arguments: ["--all"]
        )
        #expect(run.status == 0)
        #expect(run.stdout.contains("<item>"))
    }
}
