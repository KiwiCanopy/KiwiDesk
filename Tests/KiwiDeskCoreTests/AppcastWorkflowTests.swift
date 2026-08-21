import Foundation
import Testing

/// The two halves of the update channel live in two workflows,
/// and neither half reports when it goes missing (#874).
///
/// `release.yml` signs the archive it built; `changelog.yml`
/// writes the feed from the PUBLISHED release and opens the PR
/// that takes it live. Drop the signing step and the release
/// still builds, still drafts, still publishes — and every
/// installed copy is simply never offered it, with a green
/// Actions tab throughout. That is the failure
/// `docs/design-decisions.md` ▸ *No distribution channel without
/// an update path* calls unrecoverable, and nothing else in the
/// tree would notice it.
///
/// A scan over YAML, because a workflow cannot be executed here:
/// it needs a runner, a signing key and a published release. So
/// each assertion below reads a needle out of the file and every
/// one of them asserts its own input is non-empty first —
/// `.claude/rules/rule-authoring.md` names a regex that matches
/// nothing and passes as the sharpest form this suite could take.
///
/// **What this cannot see**: whether `SPARKLE_PRIVATE_KEY` is
/// set, whether the key it holds is the one whose public half
/// every build carries, and whether Cloudflare actually
/// redeploys the merged feed. The first two fail loudly inside
/// the signing step, which verifies what it produced; the third
/// is a hosting setting rather than a file.
@Suite("Appcast workflow wiring (#874)")
struct AppcastWorkflowTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    /// A workflow's executable YAML, with whole-line comments
    /// removed.
    ///
    /// Stripping is not tidiness, it is the difference between a
    /// guard and a decoration. Three assertions in the first cut
    /// of this suite were satisfied by prose: the signing step's
    /// own comment names `--ed-key-file -` while explaining why
    /// `-s` is wrong, and the sync workflow's header lists
    /// `site/public/appcast.xml` while explaining why it travels
    /// with the notes. Each would have kept passing with the
    /// mechanism deleted and only the argument for it left
    /// behind.
    private func workflow(_ name: String) throws -> String {
        let text = try String(
            contentsOf:
                repoRoot
                .appendingPathComponent(".github")
                .appendingPathComponent("workflows")
                .appendingPathComponent(name),
            encoding: .utf8
        )
        // The input assertion. A renamed or moved workflow would
        // otherwise make every needle below "not found" and this
        // suite would pass for having read nothing.
        #expect(
            !text.isEmpty,
            "\(name) is missing: every needle would pass vacuously"
        )
        // Continuations are JOINED before comments are
        // stripped, and that order is the fix rather than a
        // tidy-up. A `\\`-wrapped command is one shell line
        // pretending to be several, so quote parity counted per
        // physical line is wrong on every one of them — which
        // is how a needle parked in a trailing comment survived
        // the first version of this helper. Joining also stops
        // every needle below depending on where the YAML
        // happens to wrap.
        let joined = text.replacingOccurrences(
            of: #"\s*\\\n\s*"#,
            with: " ",
            options: .regularExpression
        )
        return
            joined
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(Self.stripComment)
            .joined(separator: "\n")
    }

    /// One line with its comment removed — WHOLE-LINE and
    /// TRAILING alike.
    ///
    /// Dropping only whole-line comments left the hole this
    /// helper exists to close: a mutation that moved the signing
    /// key onto disk and parked `--ed-key-file - -p "$ARCHIVE"`
    /// in a trailing `# was: …` kept every needle in this suite
    /// matched while the mechanism was gone.
    ///
    /// A `#` counts as a comment only when it follows whitespace
    /// AND the quotes before it on the line are balanced. Both
    /// clauses are load-bearing against real lines in these
    /// workflows: `"${TAG#v}"` is parameter expansion inside a
    /// quoted string, not a comment, and it is neither preceded
    /// by whitespace nor outside quotes.
    private static func stripComment(
        _ line: Substring
    ) -> String {
        if line.trimmingCharacters(in: .whitespaces)
            .hasPrefix("#")
        {
            return ""
        }
        var quotes = 0
        var kept = ""
        var previous: Character?
        for character in line {
            if character == "\"" || character == "'" {
                quotes += 1
            }
            if character == "#", quotes % 2 == 0,
                previous?.isWhitespace == true
            {
                break
            }
            kept.append(character)
            previous = character
        }
        return kept
    }

    // MARK: - release.yml produces the signature

    /// `-s` is refused by sign_update for a key in the current
    /// format, after a deprecation warning that reads like a
    /// warning. A release cut with it fails at the signing step;
    /// worse, an earlier draft of this lane prescribed it.
    @Test("the archive is signed through stdin, never with -s")
    func signsThroughStdin() throws {
        let yaml = try workflow("release.yml")
        // The whole invocation, not the flag. `--ed-key-file -`
        // alone is also how the verification call reads, so a
        // signing call switched to `-s` would leave the loose
        // needle satisfied by the step that follows it.
        #expect(
            yaml.contains(#"--ed-key-file - -p "$ARCHIVE""#),
            "the signing call must take the key on stdin"
        )
        #expect(
            !yaml.contains(#""$TOOL" -s"#),
            "-s is refused for a current-format key"
        )
    }

    /// The signature is verified before it is shipped. Without
    /// this, a corrupt secret produces a well-formed signature
    /// that no installed copy accepts — a failure that happens
    /// on every user's machine and on none of ours.
    @Test("the signature is verified before it is attached")
    func verifiesWhatItSigned() throws {
        let yaml = try workflow("release.yml")
        // NOT a bare `--verify`: the tag job already runs
        // `git rev-parse -q --verify origin/main`, so the loose
        // needle passed with this whole check deleted.
        #expect(
            yaml.contains("--verify --ed-key-file -"),
            "the signature must be verified against the key"
        )
    }

    /// The sidecar is what carries the signature to the job that
    /// writes the feed, which never holds the key.
    @Test("the signature is attached to the release")
    func attachesTheSidecar() throws {
        let yaml = try workflow("release.yml")
        // What goes INTO the array, not merely that the array is
        // passed. This guard was inert on its first cut for
        // exactly that reason: deleting the append left
        // `UPLOADS=("$ARCHIVE")` behind, so both `${UPLOADS[@]}`
        // needles still matched and a bare `.edsig` needle was
        // satisfied by the superseded-asset cleanup further
        // down — the sidecar reached no release and the suite
        // stayed green.
        #expect(
            yaml.contains(#"UPLOADS+=("$SIDECAR")"#),
            "the signature must be put into the upload set"
        )
        #expect(
            yaml.contains(
                "SIDECAR: ${{ steps.edsig.outputs.path }}"
            ),
            "the draft step must be handed the signing step's path"
        )
        #expect(
            yaml.contains(#"gh release upload "$TAG" "${UPLOADS[@]}""#),
            "the upload must carry the set, not the archive alone"
        )
        #expect(
            yaml.contains(#"gh release create "$TAG" "${UPLOADS[@]}""#),
            "a first draft takes create; every later run takes upload"
        )
    }

    /// GitHub does not expose `secrets` to a step-level `if`, so
    /// the presence of the key is lifted into an output first.
    /// Reaching for `secrets.SPARKLE_PRIVATE_KEY` in a condition
    /// reads empty and skips the step silently — which ships an
    /// unsigned release that looks exactly like a signed one
    /// until the feed refuses it.
    @Test("the key's presence is lifted into a step output")
    func keyPresenceIsAnOutput() throws {
        let yaml = try workflow("release.yml")
        #expect(yaml.contains("sparkle=true"))
        #expect(yaml.contains("sparkle=false"))
        #expect(
            yaml.contains(
                "if: steps.creds.outputs.sparkle == 'true'"
            )
        )
        #expect(
            !yaml.contains(
                "if: ${{ secrets.SPARKLE_PRIVATE_KEY }}"
            )
        )
    }

    /// The check that makes the signature mean anything.
    /// Signing and verifying with one key proves the secret is
    /// self-consistent and nothing else — a valid but WRONG key
    /// passes it, and the release then ships an update every
    /// installed copy refuses.
    @Test("the signing key is matched against SUPublicEDKey")
    func keyMatchesShippedPublicKey() throws {
        let yaml = try workflow("release.yml")
        #expect(
            yaml.contains("sparkle-public-key.js"),
            "the public half must be derived from the secret"
        )
        #expect(
            yaml.contains("read-plist-key SUPublicEDKey"),
            "and compared against what the packager ships"
        )
        #expect(
            yaml.contains(#"[ "$ACTUAL_PUB" != "$EXPECTED_PUB" ]"#),
            "a mismatch must stop the release"
        )
    }

    /// A run that produces no signature must DROP any signature
    /// an earlier run left, because `--clobber` has just
    /// replaced the archive bytes underneath it. Keeping it
    /// pairs a well-formed signature with bytes it does not
    /// sign, and `appcast-sync` pairs by name — so the release
    /// enters the feed and every installed copy downloads it
    /// and then refuses to install.
    @Test("a superseded signature is dropped, never kept")
    func supersededSignatureIsDropped() throws {
        let yaml = try workflow("release.yml")
        #expect(
            yaml.contains(#"SIBLING_SIG="$KEEP.edsig""#),
            "with no new signature the old one is superseded"
        )
        #expect(
            yaml.contains(#"KEEP_SIG="""#),
            "and must not be on the keep list"
        )
    }

    // MARK: - release.yml does NOT write the feed

    /// The whole ordering argument in one assertion: the feed is
    /// not written where the draft is made. An item created at
    /// tag time advertises a draft's asset URL, which 404s for
    /// everyone without auth, for as long as the highlights take
    /// to curate.
    @Test("the drafting workflow never writes the feed")
    func draftWorkflowDoesNotWriteTheFeed() throws {
        let code = try workflow("release.yml")
        #expect(code.contains("gh release"), "the scan read code")
        #expect(!code.contains("appcast-sync"))
        #expect(!code.contains("appcast.xml"))
    }

    // MARK: - changelog.yml publishes it

    @Test("the sync workflow writes the feed on publish")
    func syncWorkflowWritesTheFeed() throws {
        let yaml = try workflow("changelog.yml")
        #expect(yaml.contains("scripts/appcast-sync --all"))
        #expect(yaml.contains("release:\n    types: [published]"))
    }

    /// `--all` skips a release it cannot offer with a printed
    /// reason, which is right for history and useless for the
    /// release that just went out. Held strictly, a publish whose
    /// signing failed reds and names why; without it, that run
    /// writes a feed silently missing the newest version and
    /// reports success.
    @Test("the just-published release is held strictly")
    func publishedReleaseIsCheckedStrictly() throws {
        let yaml = try workflow("changelog.yml")
        // The whole invocation. A bare `--check` needle was
        // decoration: `changelog-sync --release "$TAG" --check`
        // sits four lines above and kept it matched with the
        // appcast pass deleted outright.
        #expect(
            yaml.contains(
                #"appcast-sync --release "$PUBLISHED""#
            ),
            "the published tag must be held to every clause"
        )
        #expect(
            yaml.contains(
                "PUBLISHED: ${{ github.event.release.tag_name }}"
            ),
            "the strict pass keys on the event's tag, not a dispatch"
        )
        #expect(
            !yaml.contains(
                #"appcast-sync --release "$PUBLISHED" --check"#
            ),
            "on a publish it must WRITE, not only verify"
        )
    }

    /// Both files in one commit. Split across two PRs, one can
    /// merge without the other and the site and the update window
    /// then describe different releases.
    @Test("the notes and the feed land in one commit")
    func bothArtifactsInOnePR() throws {
        let yaml = try workflow("changelog.yml")
        #expect(
            yaml.contains(
                "SYNCED=(site/src/data/changelog.json\n"
                    + "                  site/public/appcast.xml)"
            ),
            "both files must be in the one synced list"
        )
        #expect(yaml.contains(#"git add "${SYNCED[@]}""#))
    }

    /// A PR opened with `github.token` fires no workflows, so
    /// `site.yml` never runs on the sync PR — and `site.yml` is
    /// where the "is the feed actually served" check lives.
    /// Without this call the feed is the one artifact that
    /// reaches `main` with its own guard never having read it.
    @Test("the sync PR runs the site gate before it exists")
    func syncPRRunsTheSiteGate() throws {
        let yaml = try workflow("changelog.yml")
        #expect(
            yaml.contains(
                "python3 ../scripts/check-site-tokens.py --dist dist"
            ),
            "the feed's own guard must run before the PR opens"
        )
    }

    /// The shipped feed URL and the file the sync writes must
    /// name the same thing.
    ///
    /// This deliberately does NOT open the feed. `site/**` is on
    /// `.github/ci-ignore.txt`, so a change confined to the site
    /// skips the macOS jobs — and a suite that reads a path CI
    /// hides from it is a guard that cannot fire for the edit it
    /// watches, which `CiPathFilterTests` refuses outright. That
    /// half lives in `scripts/check-site-tokens.py`, which
    /// `site.yml` runs on every `site/**` PR against the BUILT
    /// output. What is left here is the half whose inputs CI does
    /// read: the packager and the workflow.
    @Test("the shipped URL names the file the sync writes")
    func shippedURLNamesTheSyncedFile() throws {
        guard let url = try buildAppPlistValue("SUFeedURL"),
            !url.isEmpty
        else {
            Issue.record("build-app.sh declares no SUFeedURL")
            return
        }
        guard let name = url.split(separator: "/").last else {
            Issue.record("SUFeedURL has no filename: \(url)")
            return
        }
        #expect(
            url.hasPrefix("https://"),
            "an update feed is fetched over TLS or not at all"
        )
        let yaml = try workflow("changelog.yml")
        #expect(
            yaml.contains("/\(name))"),
            "the synced path must end in the shipped feed's name"
        )
    }
}
