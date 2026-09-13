import Foundation
import Testing

/// The Desktop raise gate's site census (#1345): every Core file
/// that spells the activating raise (`AXHelper.raise(`) also
/// spells the compositor gate, and the set of such files is the
/// ruled one — a new raise site joins the census AND asks the
/// gate, or it is the bounce again. Comment-stripped substrings:
/// a gate spelled in an unrelated function of the same file
/// satisfies this scan, which the behavior suites
/// (`DesktopRaiseGateTests`, `DesktopRaiseGateArmTests`) are
/// there to catch. Here because `SourceScan` scans both trees
/// (AGENTS.md §1).
@Suite("Desktop raise gate site census (#1345)")
struct DesktopRaiseGateSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// The files that may spell the activating raise.
    private static let allowed: Set<String> = [
        "KiwiCore+FocusRaise.swift",
        "KiwiCore+PlacementBounce.swift",
        "KiwiCore+FocusEvents.swift",
        "KiwiCore+AccessibilityReturn.swift",
    ]

    /// Either spelling of the gate's consult.
    private static let gates = [
        "raiseCrossesDesktops(",
        "reassertCrossesDesktops(",
    ]

    @Test("every activating raise site is the ruled one and asks the gate")
    func raiseSitesAskTheGate() throws {
        var found: Set<String> = []
        var ungated: [String] = []
        let walker = FileManager.default.enumerator(
            at: Self.core,
            includingPropertiesForKeys: nil
        )
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            guard source.contains("AXHelper.raise(") else { continue }
            found.insert(url.lastPathComponent)
            if !Self.gates.contains(where: source.contains) {
                ungated.append(url.lastPathComponent)
            }
        }
        // Fail-shut: an empty walk found nothing to scan.
        try #require(!found.isEmpty)
        #expect(found == Self.allowed, "found \(found)")
        #expect(ungated.isEmpty, "ungated \(ungated)")
    }

    /// The raw read lives behind the seam's default alone
    /// (`DesktopCensusSeamTests`' shape): a second direct caller
    /// would reach the live WindowServer from every driven test.
    @Test("the raw on-screen read has one home, the seam's default")
    func rawReadHasOneHome() throws {
        let sites = try SourceScan.identifierSites(
            of: "FloatDetection.isOnScreen",
            under: Self.core
        )
        #expect(
            sites.map(\.file.lastPathComponent) == ["KiwiCore.swift"],
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }

    /// The gate itself has one home, reading BOTH compositor
    /// reads through their seams — the on-screen flag and the
    /// shown-Desktop host (#1410) — never state, the away ledger,
    /// the census's per-window door or the topology directly.
    @Test("the gate reads the compositor in its one home")
    func gateReadsTheCompositor() throws {
        let file = Self.core.appendingPathComponent(
            "App/KiwiCore+DesktopRaiseGate.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        try #require(!source.isEmpty)
        #expect(source.contains("func raiseCrossesDesktops("))
        #expect(source.contains("windowIsOnScreen("))
        #expect(source.contains("windowIsOnShownDesktop("))
        for banned in [
            "awayWindows", "state.windows", "allSpaces(", "isCurrent",
            "readWindowSpace", "NativeSpaces.", "FloatDetection.",
        ] {
            #expect(!source.contains(banned), .init(rawValue: banned))
        }
    }

    /// The second raw read lives behind its seam's default alone,
    /// the shape the first one takes (#1410).
    @Test("the raw shown-Desktop read has one home, the seam's default")
    func rawHostReadHasOneHome() throws {
        let sites = try SourceScan.identifierSites(
            of: "NativeSpaces.isOnShownDesktop",
            under: Self.core
        )
        #expect(
            sites.map(\.file.lastPathComponent) == ["KiwiCore.swift"],
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }

    /// Both reads default LIVE, so every suite built on
    /// `makeTestCore` would ask the host's WindowServer about a
    /// fixture id unless the factory pins them — in both twins.
    @Test("makeTestCore pins both raise-gate reads in both twins")
    func testCorePinsBothReads() throws {
        let tests = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Tests")
        let twins = ["KiwiDeskCoreTests", "KiwiDeskGuiTests"].map {
            tests.appendingPathComponent("\($0)/TestCore.swift")
        }
        for twin in twins {
            let source = try SourceScan.strippedSource(at: twin)
            #expect(
                source.contains("windowIsOnScreen = { _ in nil }")
                    && source.contains(
                        "windowIsOnShownDesktop = { _ in nil }"
                    ),
                .init(rawValue: "\(twin.lastPathComponent) misses a pin")
            )
        }
    }
}
