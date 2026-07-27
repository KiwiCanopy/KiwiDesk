import Foundation
import Testing

/// The app icon's layer art is *generated* from `assets/logo.svg`
/// by `scripts/build-icon-layers` (#89), so a change to the
/// mark's shape is reapplied by re-running it — never by editing
/// `assets/AppIcon.icon/Assets/*.svg` by hand.
///
/// `assets/README.md` says exactly that in prose. A README
/// sentence is what failed before: `BrandMasterParityTests`
/// exists because "if you edit one, mirror the edit in the other"
/// did not survive a rebrand, and the OG banner kept a retired
/// teal shell the whole time. This is the machine-checkable
/// version for the icon — without it, a `logo.svg` edit lands
/// fully green with stale layers and the icon quietly keeps the
/// old mark.
///
/// The generator is byte-deterministic (it derives its viewBox
/// from the master's own bounds and formats every coordinate to
/// three places), so this cannot flake.
@Suite("Icon layer parity")
struct IconLayerParityTests {

    /// Re-run the generator against a throwaway copy of the repo
    /// and compare its output with what is committed.
    ///
    /// The script resolves its paths from `__file__`, so it is
    /// exercised through the repo-shaped fixture exactly as
    /// shipped, rather than through a test-only override.
    @Test("The committed layers match a fresh generation")
    func layersMatchTheMaster() throws {
        let root = scriptFixtureRepoRoot()
        let icon =
            root
            .appendingPathComponent("assets")
            .appendingPathComponent("AppIcon.icon")

        let fixture = try makeIconFixture(repoRoot: root)
        defer { try? FileManager.default.removeItem(at: fixture) }

        let run = try runPythonScript(
            at:
                fixture
                .appendingPathComponent("scripts")
                .appendingPathComponent("build-icon-layers"),
            arguments: []
        )
        #expect(run.status == 0, "build-icon-layers failed")
        if run.status != 0 {
            Issue.record("stderr: \(run.stderr)")
        }

        for name in ["seeds.svg", "window.svg"] {
            let committed = try Data(
                contentsOf:
                    icon
                    .appendingPathComponent("Assets")
                    .appendingPathComponent(name)
            )
            let generated = try Data(
                contentsOf:
                    fixture
                    .appendingPathComponent("assets")
                    .appendingPathComponent("AppIcon.icon")
                    .appendingPathComponent("Assets")
                    .appendingPathComponent(name)
            )
            #expect(
                committed == generated,
                """
                assets/AppIcon.icon/Assets/\(name) is stale — \
                logo.svg changed without re-running the \
                generator, or the file was hand-edited. Run \
                scripts/build-icon-layers.
                """
            )
        }
    }

    /// The icon's background gradient is the mark's own flesh
    /// green, transcribed into `srgb:` floats in `icon.json`.
    /// The generator never writes that file, so only its
    /// read-only check ties the colour back to the master —
    /// this pins that the check is wired up and can actually
    /// fail, rather than being dead code.
    @Test("A flesh-green rebrand fails instead of drifting")
    func gradientDriftIsCaught() throws {
        let fixture = try makeIconFixture(
            repoRoot: scriptFixtureRepoRoot()
        )
        defer { try? FileManager.default.removeItem(at: fixture) }

        let master =
            fixture
            .appendingPathComponent("assets")
            .appendingPathComponent("logo.svg")
        let rebranded = try String(contentsOf: master, encoding: .utf8)
            .replacingOccurrences(of: "#a5cb5a", with: "#a55acb")
            .replacingOccurrences(of: "#89b34e", with: "#894eb3")
        try rebranded.write(to: master, atomically: true, encoding: .utf8)

        let run = try runPythonScript(
            at:
                fixture
                .appendingPathComponent("scripts")
                .appendingPathComponent("build-icon-layers"),
            arguments: []
        )
        #expect(
            run.status != 0,
            "a recoloured master regenerated silently"
        )
        #expect(run.stderr.contains("gradient uses"))
    }
}

/// A temp tree shaped like the repo, holding just what
/// `build-icon-layers` reads: the script, the mark master, and
/// the icon document. The script derives its root from its own
/// location, so the shape is the contract.
///
/// Unlike `runRepoScript`, which copies every `scripts/*.py`
/// because the localization tools share `localization_guards`,
/// this copies the one entry point. If the generator ever
/// imports a sibling module the fixture breaks — but it breaks
/// **shut**: the ImportError is a non-zero exit, which the
/// `run.status == 0` expectation catches.
private func makeIconFixture(repoRoot: URL) throws -> URL {
    let fm = FileManager.default
    let fixture = fm.temporaryDirectory
        .appendingPathComponent("icon-layers-\(UUID().uuidString)")
    try fm.createDirectory(
        at: fixture.appendingPathComponent("scripts"),
        withIntermediateDirectories: true
    )
    try fm.copyItem(
        at:
            repoRoot
            .appendingPathComponent("scripts")
            .appendingPathComponent("build-icon-layers"),
        to:
            fixture
            .appendingPathComponent("scripts")
            .appendingPathComponent("build-icon-layers")
    )
    try fm.copyItem(
        at: repoRoot.appendingPathComponent("assets"),
        to: fixture.appendingPathComponent("assets")
    )
    // Remove the copied layer art. Leaving it would seed the
    // fixture with the very files the test compares against, so
    // a generator that silently wrote nowhere would still come
    // back byte-equal — the comparison has to prove production,
    // not preservation. `main()` recreates the directory.
    try? fm.removeItem(
        at:
            fixture
            .appendingPathComponent("assets")
            .appendingPathComponent("AppIcon.icon")
            .appendingPathComponent("Assets")
    )
    return fixture
}
