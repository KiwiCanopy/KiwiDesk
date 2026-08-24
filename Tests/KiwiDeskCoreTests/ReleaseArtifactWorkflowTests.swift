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
/// So the artifact list is **read from the build step's own
/// argument array** rather than hand-listed here, and each flag
/// it finds is held to four things: a step locates it, the draft
/// step is handed that step's path, the upload set carries it,
/// and the superseded-asset cleanup routes it. A flag the map
/// below does not know reds rather than passing quietly — which
/// is what makes the next artifact type impossible to forget
/// halfway (`.claude/rules/rule-authoring.md` ▸ a number-pin
/// must derive the number).
///
/// A scan over YAML because the workflow cannot be run here: it
/// needs a runner, a certificate and a notarization profile.
/// `workflowSource` supplies the comment-stripped text and owns
/// why the stripping is load-bearing.
///
/// **Needles are scoped to the step that must carry them.** The
/// first cut asserted an env binding against the whole file, and
/// `ARCHIVE: ${{ steps.archive.outputs.path }}` occurs twice —
/// deleting the draft step's own copy left the suite green on
/// the Sparkle signing step's. A guard that reads the file where
/// it means to read one step is one mutation away from inert.
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
    /// How one `build-app.sh` artifact flag must be wired: the
    /// step id that locates it, the env name the draft step
    /// reads its path through, and the two shell variables the
    /// superseded-asset cleanup uses to keep the shipped name
    /// and drop the renamed one.
    private struct Wiring {
        let step: String
        let env: String
        let keep: String
        let sibling: String
    }

    private static let attachment: [String: Wiring] = [
        "--zip": Wiring(
            step: "archive",
            env: "ARCHIVE",
            keep: "KEEP",
            sibling: "SIBLING"
        ),
        "--dmg": Wiring(
            step: "image",
            env: "IMAGE",
            keep: "KEEP_DMG",
            sibling: "SIBLING_DMG"
        ),
    ]

    /// Flags that are not artifacts, and whether each swallows
    /// the token after it. Listing them is what lets an
    /// unrecognised flag be treated as a forgotten artifact
    /// rather than waved through.
    private static let nonArtifact: [String: Bool] = [
        "--output": true,
        "--notarize": true,
        "--identity": true,
        "--skip-build": false,
        "--allow-no-icon": false,
    ]

    /// The artifact flags the build step actually asks for.
    ///
    /// EVERY `ARGS` line is read, the conditional `ARGS+=(…)`
    /// append included — the shape `--notarize` already uses,
    /// and the one a credential-gated artifact would naturally
    /// take. Reading only the initial assignment would leave
    /// exactly that case invisible.
    private func requestedFlags(_ yaml: String) throws -> [String] {
        let lines = yaml.split(separator: "\n").filter {
            $0.contains("ARGS=(") || $0.contains("ARGS+=(")
        }
        #expect(
            !lines.isEmpty,
            "the build step no longer assembles an ARGS array"
        )
        var flags: [String] = []
        for line in lines {
            let open = try #require(line.range(of: "=("))
            let rest = line[open.upperBound...]
            let close = try #require(
                rest.firstIndex(of: ")"),
                "an ARGS array is not closed on its own line"
            )
            var skipNext = false
            for token in rest[..<close].split(separator: " ") {
                if skipNext {
                    skipNext = false
                    continue
                }
                guard token.hasPrefix("--") else { continue }
                if let swallows = Self.nonArtifact[String(token)] {
                    skipNext = swallows
                    continue
                }
                flags.append(String(token))
            }
        }
        return flags
    }

    /// One named step's own block: from its `- name:` line to
    /// the next step's. Scoping is the point — see the suite's
    /// note on the inert first cut.
    private func step(
        _ name: String,
        in yaml: String
    ) throws -> String {
        let lines = yaml.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let start = try #require(
            lines.firstIndex { $0.contains("- name: \(name)") },
            "release.yml has no step named \(name)"
        )
        var end = lines.count
        for index in (start + 1)..<lines.count
        where lines[index].hasPrefix("      - ") {
            end = index
            break
        }
        return lines[start..<end].joined(separator: "\n")
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

    /// Read the flags off the build step, and hold each one to
    /// reaching the release.
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
        let draft = try step("Draft the release", in: yaml)
        let uploads = uploadSet(draft)
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
            #expect(
                yaml.contains("id: \(wiring.step)"),
                "\(flag) is bound to a step that does not exist"
            )
            let binding =
                "\(wiring.env): ${{ steps.\(wiring.step)"
                + ".outputs.path }}"
            #expect(
                draft.contains(binding),
                "the draft step is not handed \(flag)'s path"
            )
            #expect(
                uploads.contains("$\(wiring.env)"),
                "\(flag)'s artifact is built and never attached"
            )
        }
    }

    // MARK: - Built implies cleaned up

    /// The other half of the same obligation, and the one a
    /// hand-written `.dmg` needle would have let a third
    /// artifact skip: an artifact routed into the upload set and
    /// not into the cleanup leaves the draft carrying both its
    /// names after the prescribed prove-then-add-credentials
    /// re-run, with the one a person clicks decided by which
    /// sorts first.
    @Test("every attached artifact is routed through the cleanup")
    func everyBuiltArtifactIsCleanedUp() throws {
        let yaml = try workflowSource("release.yml")
        let draft = try step("Draft the release", in: yaml)
        for flag in try requestedFlags(yaml) {
            guard let wiring = Self.attachment[flag] else {
                continue  // already recorded by the test above
            }
            let kept =
                ##"\##(wiring.keep)="$(basename "##
                + ##""$\##(wiring.env)")""##
            let derived =
                ##"\##(wiring.sibling)="$(sibling_of "##
                + ##""$\##(wiring.keep)")""##
            #expect(
                draft.contains(kept),
                "\(flag)'s kept name is not taken off the path"
            )
            #expect(
                draft.contains(derived),
                "\(flag)'s renamed sibling is not derived"
            )
            #expect(
                draft.contains(
                    ##"[ "$asset" = "$\##(wiring.sibling)" ]"##
                ),
                "\(flag)'s superseded name is never dropped"
            )
            #expect(
                draft.contains(
                    ##"[ "$asset" != "$\##(wiring.keep)" ]"##
                ),
                "\(flag)'s shipped name is not on the keep list"
            )
        }
    }

    /// `sibling_of` is the consuming side's ONE reading of
    /// `build-app.sh`'s `-unnotarized` convention, and it has to
    /// answer in both directions: the credential-less run
    /// attaches the unnotarized name and the re-run supersedes
    /// it, so a helper that only ever appended the suffix would
    /// leave the first run's artifact on the draft forever.
    @Test("the rename is read in both directions, once")
    func renameIsReadBothWays() throws {
        let draft = try step(
            "Draft the release",
            in: try workflowSource("release.yml")
        )
        #expect(
            draft.contains(
                ##"*-unnotarized) echo "${stem%-unnotarized}.$ext""##
            ),
            "an unnotarized name must resolve to the clean one"
        )
        #expect(
            draft.contains(##"*) echo "$stem-unnotarized.$ext""##),
            "and a clean name to the unnotarized one"
        )
    }

    // MARK: - The image's name comes off disk

    /// Reconstructing the name is how a ticketless artifact gets
    /// attached under a clean one: `build-app.sh` renames an
    /// image it could not staple to `-unnotarized.dmg`, and a
    /// path built from `$VERSION` reaches past that rename.
    ///
    /// The `-partial.dmg` exclusion is the other half. A count
    /// alone would miss the shape that actually threatens this
    /// step — not two images racing, which `build-app.sh` makes
    /// impossible, but a half-built one surviving ALONE after a
    /// failed staple and an EXIT trap that could not unlink it.
    @Test("the image is read off disk, never reconstructed")
    func imageNameComesOffDisk() throws {
        let yaml = try workflowSource("release.yml")
        let locate = try step("Locate the disk image", in: yaml)
        #expect(
            locate.contains("-name '*.dmg'"),
            "the image must be found, not named"
        )
        #expect(
            locate.contains("! -name '*-partial.dmg'"),
            "a half-built image must not be attachable"
        )
        #expect(
            locate.contains(##""${#images[@]}" -ne 1"##),
            "exactly one image, asserted rather than assumed"
        )
        #expect(
            !yaml.contains("KiwiDesk-$VERSION.dmg"),
            "a rebuilt name defeats the -unnotarized rename"
        )
    }
}
