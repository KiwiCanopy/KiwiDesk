import Foundation
import Testing

/// `scripts/build-app.sh`'s SDK stamp, held two ways (#1499).
///
/// SwiftPM under Xcode 27 stamps the deployment target as the
/// SDK, and AppKit draws the macOS 26 control design only for a
/// binary linked against SDK >= 26 — so a packaged build from
/// the wrong toolchain looks like a Settings regression and is
/// invisible to every test that runs the code. The script passes
/// the platform version explicitly and verifies the stamp after
/// the build; the scan clauses pin that SHAPE, and the spawned
/// clauses run the verification block itself against a real
/// Mach-O so the refusal is measured rather than read.
@Suite("Release build SDK stamp (#1499)")
struct BuildStampTests {
    private func script() throws -> String {
        try buildAppScriptWithoutComments()
    }

    private func index(
        _ needle: String,
        in text: String,
        _ comment: Comment
    ) throws -> Int {
        try buildAppScriptIndex(needle, in: text, comment)
    }

    // MARK: - The override rides the build

    @Test("the release build carries an explicit platform version")
    func buildPassesPlatformVersion() throws {
        let text = try script()
        let build = try index(
            "swift build -c release \\",
            in: text,
            "the release build line is gone"
        )
        let override = try index(
            "-Xlinker -platform_version -Xlinker macos",
            in: text,
            "the -platform_version override is gone"
        )
        // The override belongs to THIS build line, not somewhere
        // else in the file.
        #expect(override > build && override - build < 200)
        #expect(
            text.contains(#"-Xlinker "$MIN_OS" -Xlinker "$SDK_VERSION""#),
            "the override must take both derived numbers"
        )
    }

    @Test("both numbers are derived, each from its one home")
    func numbersHaveOneHome() throws {
        let text = try script()
        #expect(
            text.contains(#"MIN_OS=$(sed -n 's/.*\.macOS(\.v"#),
            "the deployment target is read off Package.swift"
        )
        #expect(
            text.contains("SDK_VERSION=$(xcrun --show-sdk-version)"),
            "the SDK version is read off the toolchain"
        )
        // The sed really extracts the target the manifest declares:
        // run it over the real Package.swift and compare with an
        // independent read. Shape, not value — a target bump moves
        // both sides together.
        let root = scriptFixtureRepoRoot()
        let manifest = try String(
            contentsOf: root.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let declared = try #require(
            manifest.firstMatch(of: /\.macOS\(\.v(\d+)\)/)?.1,
            "Package.swift declares no macOS deployment target"
        )
        let run = try spawn(
            "/bin/bash",
            [
                "-c",
                #"sed -n 's/.*\.macOS(\.v\([0-9][0-9]*\)).*/\1.0/p' "#
                    + "\"$1\" | head -1", "_",
                root.appendingPathComponent("Package.swift").path,
            ]
        )
        #expect(
            run.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                == "\(declared).0"
        )
    }

    // MARK: - The verification

    @Test("the stamp is verified after the build, before packaging")
    func verificationOrder() throws {
        let text = try script()
        let skipGate = try index(
            #"if [ "$SKIP_BUILD" -eq 0 ]; then"#,
            in: text,
            "the --skip-build gate is gone"
        )
        let verify = try index(
            #"STAMPED_SDK=$(otool -l "$BUILT/KiwiDesk""#,
            in: text,
            "the otool stamp read is gone"
        )
        let copy = try index(
            #"ditto "$SPARKLE_SRC""#,
            in: text,
            "the framework copy is gone"
        )
        // After the gate, so a reused binary is verified too;
        // before the first packaging step, so nothing is staged
        // from a binary that will be refused.
        #expect(skipGate < verify)
        #expect(verify < copy)
    }

    /// The block between the otool read and the success echo,
    /// run under bash with `$BUILT` pointing at a real Mach-O and
    /// `$SDK_VERSION` set by the test.
    private func runVerification(
        sdkVersion: String
    ) throws -> ScriptRun {
        let text = try script()
        let start = try index(
            #"STAMPED_SDK=$(otool -l "$BUILT/KiwiDesk""#,
            in: text,
            "the otool stamp read is gone"
        )
        let end = try index(
            #"echo "    stamp: minos"#,
            in: text,
            "the success echo is gone"
        )
        #expect(start < end)
        let from = text.index(text.startIndex, offsetBy: start)
        let to = text.index(text.startIndex, offsetBy: end)
        let block = String(text[from..<to])

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("build-stamp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: "/bin/ls"),
            to: dir.appendingPathComponent("KiwiDesk")
        )
        return try spawn(
            "/bin/bash",
            [
                "-c",
                "set -euo pipefail\n"
                    + "BUILT=\"$1\"; SDK_VERSION=\"$2\"; MIN_OS=x\n"
                    + block,
                "_", dir.path, sdkVersion,
            ]
        )
    }

    /// The stamp `/bin/ls` really carries, read the way the
    /// script reads it, so the matching clause asserts against
    /// the machine rather than a guessed number.
    private func stampOfBinLs() throws -> String {
        let run = try spawn(
            "/bin/bash",
            [
                "-c",
                "otool -l /bin/ls | awk '/LC_BUILD_VERSION/ {v=1}"
                    + " v && $1 == \"sdk\" {print $2; exit}'",
            ]
        )
        let stamp = run.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try #require(!stamp.isEmpty, "otool read no stamp off /bin/ls")
        return stamp
    }

    @Test("a mismatched stamp is refused with the reason")
    func mismatchRefuses() throws {
        let run = try runVerification(sdkVersion: "1.0")
        #expect(run.status != 0)
        #expect(run.stderr.contains("#1499"))
        #expect(run.stderr.contains("is stamped sdk"))
    }

    @Test("a matching stamp passes, judged on major.minor")
    func matchPasses() throws {
        let stamp = try stampOfBinLs()
        let parts = stamp.split(separator: ".").map(String.init)
        try #require(parts.count >= 2)
        // Same major.minor, a different patch component — the
        // comparison the script owes, since otool prints the
        // encoded version and the SDK query does not.
        let query = "\(parts[0]).\(parts[1]).9"
        let run = try runVerification(sdkVersion: query)
        #expect(run.status == 0, "stderr: \(run.stderr)")
        #expect(run.stderr.isEmpty)
    }
}
