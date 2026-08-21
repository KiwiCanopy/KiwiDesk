import Foundation
import Testing

/// `release.yml` signs the archive it built (#874), and none of
/// that reports when it goes missing.
///
/// Drop the signing step and the release still builds, still
/// drafts, still publishes — and every installed copy is simply
/// never offered it, with a green Actions tab throughout. That
/// is the failure `docs/design-decisions.md` ▸ *No distribution
/// channel without an update path* calls unrecoverable, and
/// nothing else in the tree would notice it.
///
/// A scan over YAML, because a workflow cannot be executed here:
/// it needs a runner, a signing key and a published release.
/// `workflowSource` supplies the comment-stripped text and owns
/// why the stripping matters.
///
/// **What this cannot see**: whether `SPARKLE_PRIVATE_KEY` is
/// set. Whether it is the RIGHT key is now checked by the
/// workflow itself, which derives the public half and compares
/// it to the shipped `SUPublicEDKey`.
@Suite("Appcast signing workflow (#874)")
struct AppcastSigningWorkflowTests {
    private func workflow(_ name: String) throws -> String {
        try workflowSource(name)
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
            yaml.contains(#"STALE_SIG="$KEEP.edsig""#),
            "with no new signature the old one is superseded"
        )
        #expect(
            yaml.contains(#"[ "$asset" = "$STALE_SIG" ]"#),
            "and the cleanup must actually test for it"
        )
        #expect(
            yaml.contains(#"[ -n "$STALE_SIG" ]"#),
            "guarded on being SET, so an empty one matches nothing"
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
}
