import Foundation
import Testing

/// `scripts/build-app.sh`'s Sparkle steps, held by ORDER (#874).
///
/// Every one of these is invisible on the machine that runs the
/// script — `.claude/rules/packaging-and-release.md`'s premise —
/// and each fails somewhere else entirely:
///
/// - drop the `ditto` and the app launches, then dies on a
///   missing `@rpath` framework;
/// - drop the `install_name_tool` and the same, on a machine
///   where `.build` does not happen to sit beside it;
/// - run either AFTER signing and the signature is invalidated by
///   the very step meant to complete the bundle;
/// - sign three of the four nested pieces and notarization
///   rejects the app — on Apple's servers, days later, from a
///   build that verified perfectly here.
///
/// A shell script cannot be unit-tested for behaviour without
/// running a signing identity, so this guards the ORDERING, which
/// is what all four failures are. The repo already scans this
/// script (`ScriptStampTests`, `AppPlistLocalizationTests`), so
/// the shape is precedent rather than a new idea.
@Suite("Sparkle packaging order (#874)")
struct SparklePackagingTests {
    private func script() throws -> String {
        let url = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("build-app.sh")
        let raw = try String(contentsOf: url, encoding: .utf8)
        // Shell comments are stripped, and that is load-bearing
        // rather than tidiness: without it a COMMENTED-OUT entry
        // satisfies every needle below, so deleting `Updater.app`
        // from the signing list by commenting it passes — proved
        // by mutation before this line existed. The same trap
        // `.claude/rules/gui.md` names, where a comment quoting a
        // deleted key stood in for its call site.
        //
        // Cut at the first `#` on a line, never mid-line: a `#`
        // inside a plist heredoc (`<key>…`) is not a comment, and
        // the keys asserted below live in one.
        let text = raw.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map { line -> Substring in
            let body = line.drop { $0 == " " || $0 == "\t" }
            return body.hasPrefix("#") ? "" : line
        }
        .joined(separator: "\n")

        // Assert the input before asserting anything about it: a
        // scan over an empty string passes every ordering check
        // by finding nothing, which reads exactly like passing.
        #expect(text.count > 1000, "build-app.sh looks empty")
        return text
    }

    private func index(
        _ needle: String,
        in text: String,
        _ comment: Comment
    ) throws -> Int {
        let range = try #require(
            text.range(of: needle),
            comment
        )
        return text.distance(
            from: text.startIndex,
            to: range.lowerBound
        )
    }

    /// The framework has to be in place, and the executable has
    /// to know where to look, before anything is sealed.
    @Test("the copy and the rpath precede all signing")
    func embedBeforeSigning() throws {
        let text = try script()
        let copy = try index(
            #"ditto "$SPARKLE_SRC""#,
            in: text,
            "the framework copy is gone"
        )
        let rpath = try index(
            "install_name_tool -add_rpath",
            in: text,
            "the rpath is gone — the app cannot find Sparkle"
        )
        let signing = try index(
            #"echo "==> codesign"#,
            in: text,
            "the signing step is gone"
        )
        #expect(copy < signing)
        #expect(
            rpath < signing,
            """
            install_name_tool rewrites the Mach-O load commands, \
            so running it after codesign invalidates the very \
            signature it comes after.
            """
        )
    }

    /// Inside-out: each nested piece, then the framework, then
    /// the app. The list is asserted as a SET as well as an
    /// order, so deleting one entry reds rather than quietly
    /// signing three of four.
    @Test("the nest is signed inside-out, and wholly")
    func nestSignedInsideOut() throws {
        let text = try script()
        let nested = [
            "XPCServices/Downloader.xpc",
            "XPCServices/Installer.xpc",
            "Autoupdate",
            "Updater.app",
        ]
        let loop = try index(
            #"for nested in \"#,
            in: text,
            "the nested-signing loop is gone"
        )
        let framework = try index(
            #"--sign "$IDENTITY" "$SPARKLE_FW""#,
            in: text,
            "the framework itself is never signed"
        )
        let app = try index(
            #"--sign "$IDENTITY" "$APP""#,
            in: text,
            "the app itself is never signed"
        )
        for piece in nested {
            let at = try index(
                "\"\(piece)\"",
                in: text,
                "\(piece) is not in the signing list"
            )
            #expect(
                at > loop && at < framework,
                "\(piece) is not signed inside the nest loop"
            )
        }
        #expect(framework < app)
    }

    /// A missing nested piece means Sparkle's layout moved on a
    /// version bump. Continuing past it would sign what is left
    /// and ship an app that fails notarization, so the script
    /// refuses — and that refusal is the thing worth pinning,
    /// because `|| continue` is a one-token edit away.
    @Test("a missing nested piece is refused, not skipped")
    func missingPieceIsFatal() throws {
        let text = try script()
        let guardIndex = try index(
            #"if [ ! -e "$SPARKLE_V/$nested" ]; then"#,
            in: text,
            "the missing-piece check is gone"
        )
        let exitIndex = try index(
            "Sparkle's\" \\\n             \"nested layout changed",
            in: text,
            "the refusal no longer names what went wrong"
        )
        #expect(exitIndex > guardIndex)
    }

    /// Both keys are permanent once a build ships: an installed
    /// copy only ever looks at this feed and only ever trusts
    /// this key, so a change to either reaches nobody who has not
    /// already updated. Pinned so moving one is a deliberate act.
    @Test("the feed and the public key are in the plist")
    func plistCarriesTheSparkleKeys() throws {
        let text = try script()
        #expect(text.contains("<key>SUFeedURL</key>"))
        #expect(text.contains("<key>SUPublicEDKey</key>"))
        // Unset, Sparkle asks the user its own question with a
        // modal, from an app with no Dock tile.
        #expect(text.contains("<key>SUEnableAutomaticChecks</key>"))
    }
}
