import Foundation
import Testing

/// One ring for both of the app's cycles (#3131): Open or
/// Focus's repeat press (#637) and `focus_app_window` step the
/// app's windows through the one `cycleAppWindow`, which builds
/// the ring with the one `cycleRing`. A second copy of the ring
/// would drop the away reach (#1146), the frontmost check
/// (#1785), the sticky arm (#414) or the overlay exclusion the
/// day one copy changed — and the behaviour suites stay green
/// beside a copy that agrees today, so the source half is
/// pinned here; `FocusAppWindowTests` ▸
/// `nextMatchesTheRepeatPress` is the behaviour half.
@Suite("Both app cycles share one ring (#3131)")
struct AppWindowCycleSeamTests {
    private static let core = SourceScan.repoRoot(
        from: #filePath
    ).appendingPathComponent("Sources/KiwiDeskCore")
    private static let cycleFile = "KiwiCore+LaunchCycle.swift"
    private static let verbFile = "KiwiCore+FocusAppWindow.swift"

    /// needle → file → count, across the whole Core tree: the
    /// step's declaration and its two callers (Open or Focus and
    /// the focused-app entry), that entry and its one caller, the
    /// verb, and the ring's
    /// declaration, its two readers in the cycle file and the
    /// ruled `move_here` reader (#1513).
    private static let sites: [(String, [String: Int])] = [
        (
            "cycleAppWindow(",
            [cycleFile: 2, "KiwiCore+Launch.swift": 1]
        ),
        ("cycleFocusedAppWindow(", [cycleFile: 1, verbFile: 1]),
        (
            "cycleRing(",
            [cycleFile: 3, "KiwiCore+MoveHere.swift": 1]
        ),
    ]

    @Test("the cycle and its ring have the pinned sites only")
    func sitesArePinned() throws {
        for (needle, expected) in Self.sites {
            let found = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            var counts: [String: Int] = [:]
            for site in found {
                counts[site.file.lastPathComponent, default: 0] += 1
            }
            #expect(counts == expected, "\(needle): \(counts)")
        }
    }

    /// The verb's file steps the shared cycle and builds no ring:
    /// the spellings a hand-built ring needs are absent from the
    /// whole file, a private helper beside the verb included.
    @Test("focus_app_window steps the shared cycle and builds no ring")
    func verbBuildsNoRing() throws {
        let file = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Commands/\(Self.verbFile)"
            )
        )
        #expect(file.contains("cycleFocusedAppWindow("))
        #expect(file.contains("verb: \"focus_app_window\""))
        for spelling in [
            "cycleRing(", "withAwayMembers(", "allSpaces",
            "awayReach(", "appBundleID", "%",
        ] {
            #expect(!file.contains(spelling), "\(spelling)")
        }
    }

    /// The step's target focus carries the calling verb to the
    /// away reach; a hard-coded label there names Open or Focus
    /// on every `focus_app_window` reach.
    @Test("the reach takes the calling verb")
    func reachTakesTheCallingVerb() throws {
        let body = try SourceScan.functionBody(
            of: "focusCycleTarget",
            in: Self.cycleFile,
            under: "Commands"
        )
        #expect(body.contains("verb: verb"))
        #expect(!body.contains("verb: \""))
    }
}
