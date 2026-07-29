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
/// copy of who may (`.claude/rules/parity-tests.md`); grow it
/// only with a seam argument in the nominee's doc comment.
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
        // The seam itself must exist, or the scan is looking at
        // the wrong tree.
        #expect(!sites.isEmpty)
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
    @Test("exec-child suites stay in the ExecTests partition")
    func execChildSuites() throws {
        let sites = try Self.sites(
            of: "exec.launch" + "(",
            under: Self.testTrees
        )
        // The partition must be inhabited, or the needle rotted.
        #expect(!sites.isEmpty)
        let strays = sites.filter {
            !$0.file.lastPathComponent.hasPrefix("ExecTests")
        }
        let listed = strays.map(\.site)
            .joined(separator: ", ")
        #expect(
            strays.isEmpty,
            "real shell children outside --skip: \(listed)"
        )
    }

    @Test("the makeTestCore twins are identical")
    func testCoreTwins() throws {
        let twins = Self.testTrees.map {
            $0.appendingPathComponent(Self.coreFactory)
        }
        let factories = try twins.map {
            try SourceScan.normalizedFunction(
                named: "makeTestCore",
                in: $0
            )
        }
        let registrars = try twins.map {
            try SourceScan.normalizedFunction(
                named: "register",
                in: $0
            )
        }
        // nil means the walk failed — red, never skip.
        #expect(!factories.contains(nil))
        #expect(!registrars.contains(nil))
        #expect(
            factories[0] == factories[1],
            "makeTestCore twins drifted — desynced seams"
        )
        #expect(registrars[0] == registrars[1])
    }
}
