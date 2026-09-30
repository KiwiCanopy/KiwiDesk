import Foundation
import Testing

/// Core carries no SwiftUI motion starter (#1078), split from
/// `BarMotionSeamTests` at the §2.1 ceiling: the two suites guard
/// different answers — a route through `BarMotion` there, a
/// per-call gate here.
@Suite("Core carries no SwiftUI motion (#1078)")
struct BarMotionSwiftUISeamTests {
    private static var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// SwiftUI's starters, held at ZERO in Core rather than
    /// added to `starters`, because the two lists earn different
    /// answers and merging them would give the wrong one. A
    /// SwiftUI animation carries an argument, so it takes
    /// `ReduceMotionGateTests`' per-call gate — NOT a route
    /// through a `BarMotion`, which is what a `starters` entry
    /// would demand. So the first one to land in Core reds here
    /// and its author widens that suite's root instead.
    private static let swiftUIStarters = [
        "withAnimation", ".animation", ".transaction",
        "phaseAnimator", "keyframeAnimator", "symbolEffect",
        "contentTransition",
    ]

    @Test("No SwiftUI starter ships unscanned in Core")
    func noSwiftUIStarterArrives() throws {
        var found: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(
            under: Self.coreRoot
        ) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
            let text = Array(source)
            for spelling in Self.swiftUIStarters
            where source.contains(spelling)
                && !SourceScan.callSites(
                    in: text,
                    for: spelling,
                    closureCounts: true
                ).isEmpty
            {
                found.append(
                    "\(file.lastPathComponent): \(spelling)"
                )
            }
        }
        // Its OWN floor, not the sibling's: borrowed non-vacuity
        // dies the day the clause that lends it is split out or
        // renamed (guard-prover).
        #expect(scanned >= 200, "scanned \(scanned) files")
        #expect(
            found.isEmpty,
            """
            a SwiftUI surface arrived in Core: gate it per call \
            the way `Sources/KiwiDesk` does and widen \
            ReduceMotionGateTests' root to reach it, rather than \
            routing it through BarMotion: \(found)
            """
        )
    }
}
