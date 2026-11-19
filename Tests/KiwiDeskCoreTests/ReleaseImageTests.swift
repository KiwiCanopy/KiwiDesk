import Foundation
import Testing

/// A release may carry ONE image, `site/public/releases/<v>.png`
/// (owner ruling 2026-11-19): `changelog-sync` records its route
/// as `image` only when the file is in the tree, `discord-announce`
/// makes it the embed's image, and `release.yml` opens the draft's
/// body with it. The feed never carries it: `appcast-sync` over an
/// imaged entry here, the built `appcast.xml` in
/// `scripts/check-site-tokens.py` ▸ `check_release_images`.
///
/// Every run names `--images` at a temporary directory: the real
/// tree carries images, and a plausible tag would read them.
@Suite("Release image")
struct ReleaseImageTests {
    private static let tag = "v9999.4.0"
    private static let version = "9999.4.0"
    private static let route = "/releases/9999.4.0.png"

    private static let highlights = """
        ## Highlights

        A summary sentence about the release.

        ### New

        - **A thing changed.** And here is how.
        """

    private func script(_ name: String) -> URL {
        scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent(name)
    }

    /// A fresh image directory, holding this release's PNG or not.
    private func images(carrying: Bool) throws -> URL {
        let dir = testTemporaryDirectory.appendingPathComponent(
            "release-images-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        if carrying {
            try Data([0x89]).write(
                to: dir.appendingPathComponent("\(Self.version).png")
            )
        }
        return dir
    }

    private func releases(body: String) throws -> URL {
        let release: [String: Any] = [
            "tag_name": Self.tag,
            "published_at": "2026-11-19T10:00:00Z",
            "draft": false,
            "html_url": "https://example.invalid/release",
            "body": body,
            "assets": [],
        ]
        let file = testTemporaryDirectory.appendingPathComponent(
            "release-image-\(UUID().uuidString).json"
        )
        try JSONSerialization.data(withJSONObject: [release])
            .write(to: file)
        return file
    }

    private func object(_ run: ScriptRun) throws -> [String: Any] {
        #expect(run.status == 0, "\(run.stderr)")
        let parsed =
            try JSONSerialization
            .jsonObject(with: Data(run.stdout.utf8)) as? [String: Any]
        return try #require(parsed)
    }

    private func entry(carrying: Bool) throws -> [String: Any] {
        let run = try runPythonScript(
            at: script("changelog-sync"),
            arguments: [
                "--all",
                "--releases", try releases(body: Self.highlights).path,
                "--images", try images(carrying: carrying).path,
                "--output", "-",
            ]
        )
        let list = try object(run)["releases"] as? [[String: Any]]
        return try #require(list?.first)
    }

    /// The deployed site, read off the bundle's `SUFeedURL` — the
    /// origin `release-announce.yml` waits on. `site/` is CI-ignored,
    /// so the site gate holds that host to `astro.config.mjs`
    /// (`scripts/check-site-tokens.py` ▸ `check_appcast`).
    private func siteOrigin() throws -> String {
        let source = try String(
            contentsOf: script("build-app.sh"),
            encoding: .utf8
        )
        let match = try #require(
            source.firstMatch(
                of: /<string>(https:\/\/[^\/<]+)\/appcast\.xml</
            )
        )
        return String(match.1)
    }

    private func imageLine(carrying: Bool) throws -> String {
        let run = try runPythonScript(
            at: script("changelog-sync"),
            arguments: [
                "--image-line", Self.version,
                "--images", try images(carrying: carrying).path,
            ]
        )
        #expect(run.status == 0, "\(run.stderr)")
        return run.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("the entry names the image only when the tree has it")
    func entryImageFollowsTheFile() throws {
        #expect(try entry(carrying: true)["image"] as? String == Self.route)
        #expect(try entry(carrying: false)["image"] == nil)
    }

    @Test("the page's opening line is the image on the site")
    func imageLineIsAbsolute() throws {
        let origin = try siteOrigin()
        #expect(
            try imageLine(carrying: true)
                == "![KiwiDesk \(Self.version)](\(origin)\(Self.route))"
        )
        #expect(try imageLine(carrying: false).isEmpty)
    }

    /// The opening line sits above `## Highlights`, so the parser
    /// never reads it as notes; a body that lost it is warned
    /// about, never refused.
    @Test("a body without its image line warns, and still passes")
    func missingLineWarns() throws {
        let line = try imageLine(carrying: true)
        for (body, warns) in [
            ("\(line)\n\n\(Self.highlights)", false),
            (Self.highlights, true),
            ("\(line)\n\(line)\n\n\(Self.highlights)", true),
        ] {
            let run = try runPythonScript(
                at: script("changelog-sync"),
                arguments: [
                    "--release", Self.tag, "--check",
                    "--releases", try releases(body: body).path,
                    "--images", try images(carrying: true).path,
                    "--census", "/dev/null",
                    "--output", "-",
                ]
            )
            #expect(run.status == 0, "\(run.stderr)")
            #expect(run.stderr.contains(line) == warns, "\(run.stderr)")
        }
    }

    private func embed(carrying: Bool) throws -> [String: Any] {
        let run = try runPythonScript(
            at: script("discord-announce"),
            arguments: [
                "--release", Self.tag, "--dry-run",
                "--releases", try releases(body: Self.highlights).path,
                "--images", try images(carrying: carrying).path,
            ]
        )
        let embeds = try object(run)["embeds"] as? [[String: Any]]
        return try #require(embeds?.first)
    }

    @Test("the Discord embed shows the image from the site")
    func embedCarriesTheImage() throws {
        let image = try embed(carrying: true)["image"] as? [String: Any]
        #expect(
            image?["url"] as? String == "\(try siteOrigin())\(Self.route)"
        )
        #expect(try embed(carrying: false)["image"] == nil)
    }

    /// The update window stays text-only: an entry carrying
    /// `image` reaches the feed with its notes and without it.
    @Test("the feed never carries the image")
    func feedOmitsTheImage() throws {
        let entry: [String: Any] = [
            "tag": Self.tag,
            "version": Self.version,
            "image": Self.route,
            "summary": "A summary only the feed shows.",
            "sections": [
                ["title": "New", "type": "new", "items": ["**A**."]]
            ],
        ]
        let notes = try AppcastFixture.write(
            ["generated_by": "ReleaseImageTests", "releases": [entry]],
            label: "notes"
        )
        let run = try AppcastFixture.render(
            [AppcastFixture.release(tag: Self.tag)],
            arguments: ["--all", "--notes", notes.path]
        )
        #expect(run.status == 0, "\(run.stderr)")
        #expect(run.stdout.contains("A summary only the feed shows."))
        #expect(!run.stdout.contains(Self.route))
        #expect(!run.stdout.contains("\"image\""))
    }

    /// The draft is the one place every release body starts, so
    /// the line is written there, above the generated list.
    @Test("the draft opens with the image line")
    func draftPassesTheLine() throws {
        let step = try workflowStep(
            "Draft the release",
            in: try workflowSource("release.yml")
        )
        #expect(step.contains("scripts/changelog-sync"))
        #expect(step.contains("--image-line \"$VERSION\""))
        #expect(step.contains("OPENING=(--notes \"$PICTURE\")"))
        let opening = try #require(step.range(of: "${OPENING[@]"))
        let generated = try #require(
            step.range(of: "--generate-notes", options: .backwards)
        )
        #expect(opening.lowerBound < generated.lowerBound)
    }
}
