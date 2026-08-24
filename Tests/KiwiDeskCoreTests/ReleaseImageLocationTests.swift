import Foundation
import Testing

/// The disk image the release attaches is the one on disk (#968).
///
/// Split from `ReleaseArtifactWorkflowTests` on the seam that
/// suite's own subject makes: that one holds every artifact to
/// reaching the release and the cleanup, which is a rule about
/// the SET of artifacts; this one is about how a single
/// artifact's path is obtained, which is a rule about `find`.
/// The seam is clean while there is one located artifact type
/// and would not be after the next (`.claude/rules/tests.md` ▸
/// *split suites early*).
///
/// **What this cannot see**: whether the image is stapled.
/// `scripts/build-app.sh` owns the staple and the rename that
/// follows a failed one (`SparklePackagingTests` holds its
/// ordering), and only a machine that downloaded the artifact
/// can prove the ticket is attached —
/// `.claude/rules/packaging-and-release.md` ▸ *Every
/// distributable artifact needs its OWN ticket*.
@Suite("Release image location (#968)")
struct ReleaseImageLocationTests {
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
        let locate = try workflowStep("Locate the disk image", in: yaml)
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
        // Both spellings of the same reconstruction: a bare
        // `$VERSION` and the braced form. Neither is what the
        // step may do, and an exact needle for one of them is a
        // needle for the spelling rather than for the mistake.
        #expect(
            !yaml.contains("KiwiDesk-$VERSION.dmg")
                && !yaml.contains("KiwiDesk-${VERSION}.dmg"),
            "a rebuilt name defeats the -unnotarized rename"
        )
    }
}
