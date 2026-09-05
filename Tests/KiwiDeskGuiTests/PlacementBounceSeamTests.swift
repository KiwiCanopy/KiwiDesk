import Foundation
import Testing

/// The production wirings of the placement-bounce distrust
/// (#1161) that no unit fixture reaches — the
/// `FollowFocusSeamTests` shape.
///
/// `PlacementBounceTests` holds what the ledger and the verdict
/// DO. What it cannot see: a placement LEAF that stops stamping
/// (an animated pan stamps at `applyFrame`'s top, and the
/// fixture's instant retile is stamped by `setFrame` either
/// way), a second leaf that bypasses both, the re-assert raise
/// (`eventLoop.element(for:)` is nil under `makeTestCore`, so
/// the state half is all a fixture proves), and the handler
/// consulting the verdict at all.
@Suite("The placement-bounce distrust stays wired (#1161)")
struct PlacementBounceSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// needle → the files that may carry it, each exactly once.
    private static let wirings: [(String, [String])] = [
        // The two placement leaves every placer goes through:
        // one animated apply, one instant apply. A third leaf
        // would place without stamping — the quit teardown's
        // direct `WindowControl.setFrame` is the ruled exception,
        // the app being on its way out.
        ("animation.animate(", ["TilingEngine+Layout.swift"]),
        ("applier.applyInstant(", ["TilingEngine.swift"]),
        // The stamps at those leaves.
        (
            "placements.stamp(",
            ["TilingEngine+Layout.swift", "TilingEngine.swift"]
        ),
        // The handler consults the verdict once and answers once.
        ("placementBounce(id, now:", ["KiwiCore+FocusEvents.swift"]),
        (
            "reassertAgainstPlacementBounce(",
            ["KiwiCore+FocusEvents.swift", "KiwiCore+PlacementBounce.swift"]
        ),
    ]

    @Test("each wiring exists exactly once per named file")
    func wiringsAreSingular() throws {
        for (needle, files) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            let found = sites.map(\.file.lastPathComponent)
            #expect(
                sites.count == files.count
                    && Set(found) == Set(files),
                """
                expected `\(needle)` once in each of \
                \(files.joined(separator: ", ")), found \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }

    /// The re-assert is a RAISE, not a state-only revert: a
    /// placement bounce has no sequence whose closing re-assert
    /// would put OS focus back (docs/design-decisions.md).
    @Test("the re-assert raises the intended window")
    func reassertRaises() throws {
        let file = Self.core.appendingPathComponent(
            "App/KiwiCore+PlacementBounce.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        let body = SourceScan.declarationBody(
            after: "func reassertAgainstPlacementBounce(",
            in: source
        )
        #expect(body != nil)
        #expect(body?.contains("AXHelper.raise(") == true)
    }
}
