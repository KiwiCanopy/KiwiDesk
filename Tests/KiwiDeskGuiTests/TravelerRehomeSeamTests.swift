import Foundation
import Testing

/// The traveler re-home's wirings (#1217): a NET runs from the
/// retile, once, and routes through the one float predicate and
/// the one re-anchor math — a second copy of either is where the
/// #1178 drift re-opens.
@Suite("The traveler re-home stays wired (#1217)")
struct TravelerRehomeSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("the net runs from the retile, once")
    func theNetRunsFromTheRetile() throws {
        let sites = try SourceScan.identifierSites(
            of: "rehomeFloatingTravelers(",
            under: Self.core
        )
        let calls = sites.filter {
            $0.file.lastPathComponent == "KiwiCore+Retile.swift"
        }
        #expect(
            calls.count == 1 && sites.count == 2,
            .init(
                rawValue: "one definition and one call from the "
                    + "retile expected, found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }

    /// The "screen a frame mostly sits on" rule has ONE home,
    /// shared by `TilingEngine.screen(containing:)` and the pure
    /// decision — a second copy is where the two would drift.
    @Test("the overlap rule has one home")
    func theOverlapRuleHasOneHome() throws {
        let sites = try SourceScan.identifierSites(
            of: "GeometryUtils.rect(",
            under: Self.core
        )
        let files = Set(sites.map(\.file.lastPathComponent))
        #expect(
            files == ["TilingEngine+Layout.swift", "TravelerRehome.swift"],
            .init(
                rawValue: "expected the two consumers, found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }

    @Test("the net asks the one predicate and the one math")
    func theNetRoutesThroughTheSeams() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("App")
                .appendingPathComponent("KiwiCore+TravelerRehome.swift")
        )
        #expect(source.contains("EffectiveFloat.applies("))
        #expect(source.contains("TravelerRehome.target("))
        guard
            let net = SourceScan.declarationBody(
                after: "private func rehomeTraveler",
                in: source
            )
        else {
            Issue.record("rehomeTraveler missing")
            return
        }
        // Both the fit and the fallback clamp take the render
        // arm — two `space: space` inside the net's own body, so
        // the outer `space: spaceID` cannot satisfy this.
        #expect(
            net.contains("floatFrameFittedClearOfBars(")
                && net.components(separatedBy: "space: space")
                    .count >= 3,
            "the net fits and clamps through the RENDER space arm"
        )
        // The fit is memo-gated like the home net's (#1091): an
        // app that refused a size is not re-asked every retile.
        #expect(
            net.contains("shouldIssueFloatFit("),
            "the traveler's fit consults the refusal memo"
        )
        #expect(
            net.contains("forgetSizeBound("),
            "the re-home invalidates the size ledger (#677)"
        )
        #expect(
            source.contains("commandedFrame("),
            "the base is the commanded frame, never the echo"
        )
        #expect(
            !source.contains("isFloating ||")
                && !source.contains("== .floating"),
            """
            a NET never re-spells the float predicate, nor \
            hand-checks the mode beside it (#1178)
            """
        )
    }
}
