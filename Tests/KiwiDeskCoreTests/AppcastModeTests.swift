import Foundation
import Testing

/// The two exit-status contracts
/// `.github/workflows/changelog.yml` leans on when it publishes
/// a release (#874), neither visible from a rendered feed.
///
/// - `--all` is **tolerant**: a release it cannot offer is
///   skipped with a printed reason. Make it fatal and every
///   future publish reds forever, because the releases that
///   predate the updater have no signature and never will.
/// - `--release <tag>` is **strict**: every clause is an error.
///   Make it tolerant and the gate silently stops gating — a
///   publish whose signing failed would write a feed missing the
///   newest version and report success.
///
/// That was the gap: the first cut of these guards drove one
/// render-to-stdout mode and pinned neither, which is why
/// `--releases` is now a SOURCE any mode can read rather than a
/// mode of its own.
///
/// The notes half lives in `AppcastNotesTests`.
@Suite("Appcast sync modes (#874)")
struct AppcastModeTests {
    static let goodTag = "v9999.1.0"
    static let unsignedTag = "v9999.0.9"

    /// One offerable release and one that predates the updater.
    static func mixed() -> [[String: Any]] {
        [
            AppcastFixture.release(tag: goodTag),
            AppcastFixture.release(
                tag: unsignedTag,
                assets: [
                    AppcastFixture.asset(
                        "KiwiDesk-9999.0.9.zip",
                        tag: unsignedTag
                    )
                ]
            ),
        ]
    }

    @Test("--all skips what it cannot offer, without failing")
    func allIsTolerant() throws {
        let run = try AppcastFixture.render(
            Self.mixed(),
            arguments: ["--all"]
        )
        #expect(
            run.status == 0,
            "one unsignable release must not red every publish"
        )
        #expect(run.stderr.contains("is not offered"))
        #expect(
            run.stdout.contains(
                "<sparkle:version>9999.1.0</sparkle:version>"
            ),
            "the offerable release still reaches the feed"
        )
        #expect(
            !run.stdout.contains(
                "<sparkle:version>9999.0.9</sparkle:version>"
            )
        )
    }

    @Test("--release refuses the same release --all skipped")
    func releaseIsStrict() throws {
        let run = try AppcastFixture.render(
            Self.mixed(),
            arguments: ["--release", Self.unsignedTag, "--check"]
        )
        #expect(
            run.status != 0,
            "the tag just published must be held to every clause"
        )
        #expect(run.stderr.contains("cannot be offered"))
    }

    @Test("--release passes an offerable tag")
    func releaseAcceptsGood() throws {
        let run = try AppcastFixture.render(
            Self.mixed(),
            arguments: ["--release", Self.goodTag, "--check"]
        )
        #expect(run.status == 0)
        #expect(run.stderr.contains("is offerable"))
    }

    /// `--check` writes nothing at all, which is what makes it
    /// safe to run before the write.
    @Test("--check renders no feed")
    func checkWritesNothing() throws {
        let run = try AppcastFixture.render(
            Self.mixed(),
            arguments: ["--release", Self.goodTag, "--check"]
        )
        #expect(!run.stdout.contains("<rss"))
    }

    /// A tag with no PUBLISHED release is refused rather than
    /// quietly producing a feed without it — a draft is the case
    /// that matters, and a draft is not a published release.
    @Test("--release refuses a tag that is not published")
    func releaseRefusesUnknownTag() throws {
        let run = try AppcastFixture.render(
            [
                AppcastFixture.release(
                    tag: Self.goodTag,
                    draft: true
                )
            ],
            arguments: ["--release", Self.goodTag, "--check"]
        )
        #expect(run.status != 0)
        #expect(run.stderr.contains("still a draft"))
    }

    /// A write that verified a tag must contain it.
    ///
    /// **What this cannot see, stated rather than implied.**
    /// `run_all`'s `require` post-condition also refuses to
    /// write when the verified tag does NOT survive the
    /// rebuild, and that branch is unreachable from here: it
    /// models the two live `gh` fetches diverging, and a
    /// fixture is one list read once, so nothing a test can
    /// build makes the check pass and the rebuild disagree.
    /// The positive is what is provable, so it is what is
    /// asserted — the refusal branch is a production
    /// post-condition, deliberately kept, and the honest
    /// statement is that no test here exercises it.
    @Test("a write that verified a tag contains it")
    func writeContainsTheVerifiedTag() throws {
        let run = try AppcastFixture.render(
            Self.mixed(),
            arguments: ["--release", Self.goodTag]
        )
        #expect(run.status == 0)
        #expect(
            run.stdout.contains(
                "<sparkle:version>9999.1.0</sparkle:version>"
            ),
            "the verified tag must reach the feed it wrote"
        )
    }

    /// The notes and the feed are one corpus: the update window
    /// renders the text the changelog page renders, so neither
    /// surface owns a second copy of a release's prose.
    ///
    /// The notes come from a PINNED fixture, through `--notes`.
    /// Reading the repo's real `site/src/data/changelog.json`
    /// was wrong twice over: it is an input the fixture does not
    /// pin (`.claude/rules/tests.md` ▸ pin any default a fixture
    /// reasons from), and `site/**` is on
    /// `.github/ci-ignore.txt`, so a suite reading it is one CI
    /// skips for exactly the edits that change it —
    /// `CiPathFilterTests` refuses that outright.
    @Test("a curated summary reaches the update window")
    func curatedNotesReachTheFeed() throws {
        let summary = "A pinned summary for the coupling test."
        let notes: [String: Any] = [
            "generated_by": "AppcastModeTests",
            "releases": [
                [
                    "tag": Self.goodTag,
                    "version": "9999.1.0",
                    "summary": summary,
                    "sections": [
                        [
                            "title": "Things",
                            "items": ["**Bold** and *why*."],
                        ]
                    ],
                ]
            ],
        ]
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "appcast-notes-\(UUID().uuidString).json"
            )
        try JSONSerialization.data(withJSONObject: notes)
            .write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let run = try AppcastFixture.render(
            [AppcastFixture.release(tag: Self.goodTag)],
            arguments: ["--all", "--notes", file.path]
        )
        #expect(run.status == 0)
        #expect(
            run.stdout.contains(summary),
            "the feed must quote the notes, not copy them"
        )
        // The inline subset the site renders with
        // `marked.parseInline`, rendered the same way here.
        #expect(run.stdout.contains("<strong>Bold</strong>"))
        #expect(run.stdout.contains("<em>why</em>"))
    }

    /// `--notes` has to reach the STRICT path as well.
    ///
    /// Its first cut threaded the override through `run_all` and
    /// not `run_release`, so `--release` silently kept reading
    /// the repo's real `site/src/data/changelog.json` — the very
    /// coupling the flag was added to remove. The only test
    /// driving `--notes` used `--all`, so nothing caught it.
}
