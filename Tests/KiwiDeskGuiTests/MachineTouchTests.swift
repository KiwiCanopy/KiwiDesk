import Foundation
import Testing

/// The suite must reach the real machine only through a seam a
/// test can inject (#565). The touch is usually invisible from
/// the test tree: `StatusItemController.init` created a live
/// `NSStatusBar.system` item, so fifteen menu-bar slots leaked
/// per run while `grep NSStatusBar Tests/` returned nothing —
/// the symbol lives in the *production* initializer the tests
/// merely call. These guards therefore pin both sides:
///
/// - the production touch stays behind its injectable seam
///   (one `NSStatusBar.system` site, inside the default
///   factory);
/// - the test trees construct the dangerous types only through
///   the shared factories that neutralize their live defaults
///   (`TestCore.swift` ×2, `TestStatusItem.swift`);
/// - the two `makeTestCore` twins — one per test target, since
///   test targets cannot see each other — stay identical, so a
///   neutralization added to one cannot silently miss the
///   other.
///
/// Needles are spelled `"Name" + "("` so this file never
/// matches its own scan. Each `allowed` constant is the one
/// copy of who may — the AGENTS.md §5 allowed-map convention;
/// grow it only with a seam argument in the nominee's doc
/// comment.
@Suite("Machine-touch seams stay injected")
struct MachineTouchTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]
    private static let testTrees = [
        root.appendingPathComponent("Tests/KiwiDeskCoreTests"),
        root.appendingPathComponent("Tests/KiwiDeskGuiTests"),
    ]

    private static func sites(
        of needle: String,
        under trees: [URL]
    ) throws -> [MachineTouchSite] {
        try trees.flatMap {
            try SourceScan.identifierSites(
                of: needle,
                under: $0
            )
        }
    }

    /// The one production file that may reach the live status
    /// bar — inside `init`'s injectable default factory.
    private static let statusBarAllowed =
        "StatusItemController.swift"

    @Test("NSStatusBar.system only behind the injectable seam")
    func statusBarBehindSeam() throws {
        let sites = try Self.sites(
            of: "NSStatusBar.system",
            under: Self.productionTrees
        )
        // Exactly the seam's one default-factory site: zero
        // means the scan looks at the wrong tree, two means a
        // second touch grew beside the seam *inside* the
        // allowed file, which the stray filter cannot see.
        #expect(sites.count == 1)
        let strays = sites.filter {
            $0.file.lastPathComponent != Self.statusBarAllowed
        }
        let listed = strays.map(\.site)
            .joined(separator: ", ")
        #expect(
            strays.isEmpty,
            "live status-bar touch outside the seam: \(listed)"
        )
    }

    /// The one test file that may construct
    /// `StatusItemController` — the factory that injects the
    /// nil status-item closure.
    private static let statusItemFactory = "TestStatusItem.swift"

    @Test("tests build StatusItemController via the factory")
    func statusItemConstruction() throws {
        let sites = try Self.sites(
            of: "StatusItemController" + "(",
            under: Self.testTrees
        )
        // The factory's own construction proves the scan sees
        // through the trees.
        #expect(
            sites.contains {
                $0.file.lastPathComponent
                    == Self.statusItemFactory
            }
        )
        let strays = sites.filter {
            $0.file.lastPathComponent != Self.statusItemFactory
        }
        let listed = strays.map(\.site)
            .joined(separator: ", ")
        #expect(
            strays.isEmpty,
            "bare StatusItemController (live item): \(listed)"
        )
    }

    /// The two files that may construct `KiwiCore` — one
    /// `makeTestCore` per test target (#565: a bare `KiwiCore()`
    /// seizes the developer's global chords and the real
    /// `~/.config/KiwiDesk`).
    private static let coreFactory = "TestCore.swift"

    @Test("tests build KiwiCore via the makeTestCore twins")
    func kiwiCoreConstruction() throws {
        let sites = try Self.sites(
            of: "KiwiCore" + "(",
            under: Self.testTrees
        )
        // Both twins must be alive and constructing.
        for tree in Self.testTrees {
            let name = tree.lastPathComponent
            #expect(
                sites.contains {
                    $0.file.lastPathComponent
                        == Self.coreFactory
                        && $0.file.path.hasPrefix(tree.path)
                },
                "no \(Self.coreFactory) build under \(name)"
            )
        }
        let strays = sites.filter {
            $0.file.lastPathComponent != Self.coreFactory
        }
        let listed = strays.map(\.site)
            .joined(separator: ", ")
        #expect(
            strays.isEmpty,
            "bare KiwiCore (live hotkeys, ~/.config): \(listed)"
        )
    }

    /// Swift-side drives of the production spawner. Lua-driven
    /// spawns (`KiwiDesk.exec` inside an *executed* fixture) are
    /// out of a text scan's reach — the same string is pure data
    /// in the ManagedConfig analyses — so fixtures that run keep
    /// their exec commands inert instead (`FirstRunSeedTests`).
    ///
    /// Two axes, deliberately: `swift test --skip/--filter`
    /// matches the suite *type* name, so that is the axis the
    /// partition consumes; the *filename* prefix is only the
    /// greppable convention. Pinning the filename alone would
    /// re-open the exact escape the `ExecDedupTests` rename
    /// closed — a properly-named file declaring a stray-named
    /// suite.
    @Test("exec-child suites stay in the ExecTests partition")
    func execChildSuites() throws {
        let sites = try Self.sites(
            of: "exec.launch" + "(",
            under: Self.testTrees
        )
        // The partition must be inhabited, or the needle rotted.
        #expect(!sites.isEmpty)
        let strayFiles = sites.filter {
            !$0.file.lastPathComponent.hasPrefix("ExecTests")
        }
        let listed = strayFiles.map(\.site)
            .joined(separator: ", ")
        #expect(
            strayFiles.isEmpty,
            "real shell children outside --skip: \(listed)"
        )
        // The type axis: every @Suite declared in a spawning
        // file must carry the prefix the CLI partition matches.
        for file in Set(sites.map(\.file)) {
            let types = try SourceScan.suiteTypeNames(in: file)
            // A spawning file with no recognizable suite is a
            // walk gap — red, never a silent skip.
            #expect(
                !types.isEmpty,
                "no @Suite found in \(file.lastPathComponent)"
            )
            let strayTypes = types.filter {
                !$0.hasPrefix("ExecTests")
            }
            let names = strayTypes.joined(separator: ", ")
            #expect(
                strayTypes.isEmpty,
                "suite escapes the type partition: \(names)"
            )
        }
    }

    /// Whole-file comparison, not a hand-picked function list —
    /// a list is one more place to forget, and a neutralization
    /// added as a *new* symbol in one twin only would slip a
    /// narrower net. The twins' only legitimate differences are
    /// doc comments, which the normalization strips.
    @Test("the makeTestCore twins are identical")
    func testCoreTwins() throws {
        let twins = Self.testTrees.map {
            $0.appendingPathComponent(Self.coreFactory)
        }
        let normalized = try twins.map {
            try SourceScan.normalizedFile($0)
        }
        // An empty normalization is a gutted twin or a broken
        // walk — red, never a vacuous pass.
        #expect(!normalized.contains(""))
        #expect(
            normalized[0] == normalized[1],
            "makeTestCore twins drifted — desynced seams"
        )
    }

    /// Raw spawner constructions, so the class is sealed rather
    /// than one spelling: `exec.launch` covers the shared-core
    /// drive, this covers a test building its own `Process` or
    /// `ExecLauncher`. `ScriptFixture.swift` is the ratified
    /// spawn primitive (repo scripts, drained pipes); exec
    /// suites may also spawn raw within their partition.
    @Test("raw process spawns stay in ratified homes")
    func rawSpawnConstruction() throws {
        let processSites = try Self.sites(
            of: "Process" + "(",
            under: Self.testTrees
        )
        // ScriptFixture's own spawn proves the scan sees.
        #expect(
            processSites.contains {
                $0.file.lastPathComponent
                    == "ScriptFixture.swift"
            }
        )
        let strays = processSites.filter {
            $0.file.lastPathComponent != "ScriptFixture.swift"
                && !$0.file.lastPathComponent
                    .hasPrefix("ExecTests")
        }
        let listed = strays.map(\.site)
            .joined(separator: ", ")
        #expect(
            strays.isEmpty,
            "raw Process outside ratified homes: \(listed)"
        )
        // Pure tripwire — no live site today, so no presence
        // canary: an empty result is the desired state.
        let launcherSites = try Self.sites(
            of: "ExecLauncher" + "(",
            under: Self.testTrees
        )
        let launchers = launcherSites.map(\.site)
            .joined(separator: ", ")
        #expect(
            launcherSites.isEmpty,
            "test-built ExecLauncher: \(launchers)"
        )
    }
}
