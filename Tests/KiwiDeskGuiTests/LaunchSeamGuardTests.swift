import Foundation
import Testing

/// #673 gave Open or Focus a seam family whose touch fires on
/// **command execution** rather than on `init` — an app lookup, a
/// window census, a deminiaturize, an activate and a launch. That
/// shape falls between the two existing machine guards:
/// `MachineTouchTests` pins `KiwiCore(` *construction* and
/// `StatusItemSeamGuardTests` pins an initializer that seizes a
/// resource, so neither stops a suite calling
/// `execute("pull_or_spawn", …)` from inheriting a live
/// `NSWorkspace`.
///
/// It already bit: a command-path test brought the real Finder
/// forward on every `swift test` run, because under the runner
/// `Bundle.main.bundleIdentifier` is nil and the test's fallback
/// bundle id reached the then-unseamed `activate()`. Naming an
/// INSTALLED id would have launched that app outright.
///
/// Two sides, and both are needed: the production touch stays
/// behind the seam, and the factory hands every suite a core
/// that cannot reach it.
@Suite("Open-or-Focus launch seam (#673)")
struct LaunchSeamGuardTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let coreTree = [
        root.appendingPathComponent("Sources/KiwiDeskCore")
    ]
    private static let testTrees = SourceScan.targetTrees(
        under: root.appendingPathComponent("Tests")
    )

    private static func sites(
        of needle: String,
        under trees: [URL]
    ) throws -> [MachineTouchSite] {
        try trees.flatMap {
            try SourceScan.identifierSites(of: needle, under: $0)
        }
    }

    /// The one Core file that may LAUNCH an app — the
    /// `OpenOrFocusSeams` defaults.
    ///
    /// Deliberately only the launch surface, not every
    /// `NSWorkspace` reach: enumerating running apps has several
    /// legitimate Core homes behind their own seams
    /// (`EventLoop`'s descriptors, the desktop-focus yield), and
    /// pinning those wants its own allowed map. Starting a
    /// process is the one touch no later event undoes.
    private static let launchAllowed =
        "KiwiCore+LaunchRestore.swift"

    @Test("starting an app stays behind its seam")
    func appLaunchBehindSeam() throws {
        for needle in ["openApplication", "urlForApplication"] {
            let sites = try Self.sites(
                of: needle,
                under: Self.coreTree
            )
            // Exactly the seam's one default site, and for
            // `statusBarBehindSeam`'s reason: zero means the
            // needle rotted against a rename and the scan passes
            // for having found nothing, two means a second touch
            // grew beside the seam *inside* the allowed file,
            // where the stray filter cannot see it.
            #expect(
                sites.count == 1,
                "\(needle): expected 1 site, got \(sites.count)"
            )
            let strays = sites.filter {
                $0.file.lastPathComponent != Self.launchAllowed
            }
            let listed = strays.map(\.site)
                .joined(separator: ", ")
            #expect(
                strays.isEmpty,
                "\(needle) outside its seam: \(listed)"
            )
        }
    }

    /// The production seam is only half the net; the other half
    /// is that `makeTestCore` hands every suite a core which
    /// cannot reach it. `MachineTouchTests.testCoreTwins` catches
    /// a ONE-SIDED removal (the twins drift), but a symmetric
    /// deletion — what a cleanup commit or a merge resolution
    /// produces — reds nothing at all: proved by removing both
    /// and watching the whole suite stay green (`guard-prover`,
    /// 2026-08-02).
    ///
    /// The suite survives that removal today only because every
    /// executing call site names a fabricated bundle id, so the
    /// live lookups miss. That is the fixture holding the line,
    /// not a guard — and it stops holding the day someone writes
    /// a test naming an installed app.
    @Test("the test factory neutralizes the launch seams")
    func factoryNeutralizesLaunchSeams() throws {
        for needle in ["runningAppPID", "openApp"] {
            let sites = try Self.sites(
                of: needle,
                under: Self.testTrees
            )
            let twins = sites.filter {
                $0.file.lastPathComponent == "TestCore.swift"
            }
            // One assignment per twin, both trees. The count, not
            // mere presence, is what a symmetric deletion moves.
            #expect(
                twins.count == 2,
                """
                \(needle): expected both makeTestCore twins to \
                neutralize it, found \(twins.count)
                """
            )
        }
    }
}
