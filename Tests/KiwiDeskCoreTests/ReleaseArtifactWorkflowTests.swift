import Foundation
import Testing

/// `release.yml` attaches every artifact it builds (#968).
///
/// The failure this exists for is **built but not attached**:
/// the build step gains an artifact, the release job never
/// uploads it, and nothing anywhere reports. The run is green,
/// the notarization succeeded, the draft is simply missing a
/// download — and the first person to find out is whoever
/// follows a link to it. That is the same shape as the sidecar
/// which reached no release while every loose needle in
/// `AppcastSigningWorkflowTests` stayed green.
///
/// So the artifact list is **derived from the build step's own
/// argument array** rather than hand-listed here: a `--pkg`
/// added to that line reds this suite until it is routed to the
/// upload set as well. A list typed into the test would move the
/// copy rather than guard it
/// (`.claude/rules/rule-authoring.md` ▸ a number-pin must derive
/// the number).
///
/// A scan over YAML because the workflow cannot be run here: it
/// needs a runner, a certificate and a notarization profile.
/// `workflowSource` supplies the comment-stripped text and owns
/// why the stripping is load-bearing.
///
/// **What this cannot see**: whether the image Apple ticketed is
/// the one attached, or whether the ticket is physically on it.
/// `scripts/build-app.sh` owns the staple and the rename
/// (`SparklePackagingTests` holds its ordering), and only a
/// machine that downloaded the artifact can prove the rest —
/// `.claude/rules/packaging-and-release.md` ▸ *Every
/// distributable artifact needs its OWN ticket*.
@Suite("Release artifact workflow (#968)")
struct ReleaseArtifactWorkflowTests {
    /// Where each `build-app.sh` artifact flag is expected to
    /// surface: the step id that locates it, and the env name
    /// the draft step reads its path through.
    private static let attachment: [String: (step: String, env: String)] = [
        "--zip": ("archive", "ARCHIVE"),
        "--dmg": ("image", "IMAGE"),
    ]

    /// The artifact flags the build step actually asks for.
    ///
    /// `--output` is dropped because it names a directory, not
    /// an artifact; everything else on that line is something
    /// the job then has to attach.
    private func requestedFlags(_ yaml: String) throws -> [String] {
        let line = try #require(
            yaml.split(separator: "\n").first {
                $0.contains("ARGS=(")
            },
            "the build step no longer assembles an ARGS array"
        )
        let open = try #require(line.range(of: "ARGS=("))
        let rest = line[open.upperBound...]
        let close = try #require(
            rest.firstIndex(of: ")"),
            "the ARGS array is not closed on its own line"
        )
        var flags: [String] = []
        var skipNext = false
        for token in rest[..<close].split(separator: " ") {
            if skipNext {
                skipNext = false
                continue
            }
            guard token.hasPrefix("--") else { continue }
            if token == "--output" {
                skipNext = true
                continue
            }
            flags.append(String(token))
        }
        return flags
    }

    /// Every line that writes the upload set, joined. Both
    /// shapes count: the initial assignment and any later
    /// append.
    private func uploadSet(_ yaml: String) -> String {
        yaml.split(separator: "\n")
            .filter {
                $0.contains("UPLOADS=(") || $0.contains("UPLOADS+=(")
            }
            .joined(separator: "\n")
    }

    // MARK: - Built implies attached

    /// The whole suite in one test. Read the flags off the build
    /// step, and hold each one to reaching the release.
    @Test("every artifact the build asks for is attached")
    func everyBuiltArtifactIsAttached() throws {
        let yaml = try workflowSource("release.yml")
        let flags = try requestedFlags(yaml)
        #expect(
            flags.contains("--dmg"),
            "a release must build the promoted disk image (#968)"
        )
        #expect(
            flags.contains("--zip"),
            "and the cask's archive, which Sparkle downloads"
        )
        let uploads = uploadSet(yaml)
        #expect(
            !uploads.isEmpty,
            "no upload set found: every check below is vacuous"
        )
        for flag in flags {
            guard let wiring = Self.attachment[flag] else {
                Issue.record(
                    """
                    build-app.sh is asked for \(flag) and nothing \
                    says where that artifact is attached. Route \
                    it into UPLOADS and add it to `attachment`.
                    """
                )
                continue
            }
            let binding =
                "\(wiring.env): ${{ steps.\(wiring.step)"
                + ".outputs.path }}"
            #expect(
                yaml.contains(binding),
                "the draft step is not handed \(flag)'s path"
            )
            #expect(
                uploads.contains("$\(wiring.env)"),
                "\(flag)'s artifact is built and never attached"
            )
        }
    }

    // MARK: - The image's name comes off disk

    /// Reconstructing the name is how a ticketless artifact gets
    /// attached under a clean one: `build-app.sh` renames an
    /// image it could not staple to `-unnotarized.dmg`, and a
    /// path built from `$VERSION` reaches past that rename for a
    /// file that is not there — or, worse, one left by an
    /// earlier run that was.
    @Test("the image is read off disk, never reconstructed")
    func imageNameComesOffDisk() throws {
        let yaml = try workflowSource("release.yml")
        #expect(
            yaml.contains("-maxdepth 1 -name '*.dmg'"),
            "the image must be found, not named"
        )
        #expect(
            yaml.contains(##""${#images[@]}" -ne 1"##),
            "exactly one image, asserted rather than assumed"
        )
        #expect(
            !yaml.contains("KiwiDesk-$VERSION.dmg"),
            "a rebuilt name defeats the -unnotarized rename"
        )
    }

    // MARK: - The superseded image is dropped

    /// The prescribed sequence — prove the pipeline with no
    /// secrets, add credentials, re-run — renames the image from
    /// `-unnotarized.dmg` to `.dmg`, and `--clobber` only
    /// replaces an asset of the SAME name. Without the drop, the
    /// draft carries both, and the one a person would click is
    /// the one Gatekeeper refuses after a real download.
    @Test("a superseded disk image is dropped, never kept")
    func supersededImageIsDropped() throws {
        let yaml = try workflowSource("release.yml")
        let renamed =
            ##"SIBLING_DMG="${KEEP_DMG%.dmg}-unnotarized.dmg""##
        #expect(
            yaml.contains(renamed),
            "the renamed sibling must be derived from the kept name"
        )
        #expect(
            yaml.contains(##"[ "$asset" = "$SIBLING_DMG" ]"##),
            "and the cleanup must actually test for it"
        )
        #expect(
            yaml.contains(##"[ -n "$SIBLING_DMG" ]"##),
            "guarded on being SET, so an empty one matches nothing"
        )
        #expect(
            yaml.contains(##"[ "$asset" != "$KEEP_DMG" ]"##),
            "the image being shipped must be on the keep list"
        )
    }
}
