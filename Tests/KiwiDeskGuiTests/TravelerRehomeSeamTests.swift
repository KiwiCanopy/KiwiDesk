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
            of: "rehomeFloatingTravelers()",
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

    @Test("the net asks the one predicate and the one math")
    func theNetRoutesThroughTheSeams() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("App")
                .appendingPathComponent("KiwiCore+TravelerRehome.swift")
        )
        #expect(source.contains("EffectiveFloat.applies("))
        #expect(source.contains("TravelerRehome.target("))
        #expect(
            !source.contains("isFloating ||")
                && !source.contains("== .floating ||"),
            "a NET never re-spells the float predicate (#1178)"
        )
    }
}
