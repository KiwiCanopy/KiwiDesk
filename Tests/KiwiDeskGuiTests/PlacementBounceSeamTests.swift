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
        // The stamps at those leaves — generic, so a stamp spelled
        // anywhere else is a third site rather than invisible; the
        // distrust goes through the ledger's bounded `renew` door,
        // never a stamp, or the chain of renewals has no end.
        (
            "placements.stamp(",
            ["TilingEngine+Layout.swift", "TilingEngine.swift"]
        ),
        ("placements.renew(", ["KiwiCore+PlacementBounce.swift"]),
        // The one focus command path records the window it left;
        // a second recorder would double the trade's reach.
        ("placements.noteDisplaced(", ["KiwiCore+FocusRaise.swift"]),
        // The handler consults the verdict once and answers once.
        ("placementBounce(id, now:", ["KiwiCore+FocusEvents.swift"]),
        (
            "reassertAgainstPlacementBounce(",
            ["KiwiCore+FocusEvents.swift", "KiwiCore+PlacementBounce.swift"]
        ),
        // The self ledger's one minter is what `raiseWindow`
        // stamps through.
        (
            "stampSelfRaise(",
            [
                "KiwiCore+ClickProvenance.swift",
                "KiwiCore+FocusRaise.swift",
            ]
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

    /// The self ledger has one MINTER: `stampSelfRaise`. A raise
    /// assigning the dictionary beside it would skip the prune
    /// with nothing red. Write sites are counted over
    /// comment-stripped source: the minter's prune and stamp, the
    /// gone clear, the rekey's remove and retarget.
    @Test("the self ledger's write sites are the ruled ones")
    func selfLedgerWriteSites() throws {
        let allowed: [String: Int] = [
            "KiwiCore+ClickProvenance.swift": 2,
            "KiwiCore+CloseReturnRestack.swift": 1,
            "KiwiCore+RekeyEvent.swift": 2,
            "KiwiCore.swift": 1,
        ]
        let pattern =
            #"selfRaiseStamps(\[(?:[^\[\]]|\[[^\[\]]*\])*\])?"#
            + #"\s*(=(?!=)|\.(removeValue|"#
            + #"updateValue|removeAll|merge|filter\b.*\)\s*$)|:)"#
        let writes = try NSRegularExpression(pattern: pattern)
        var found: [String: Int] = [:]
        let walker = FileManager.default.enumerator(
            at: Self.core,
            includingPropertiesForKeys: nil
        )
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            let range = NSRange(
                source.startIndex...,
                in: source
            )
            let count = writes.numberOfMatches(
                in: source,
                range: range
            )
            if count > 0 { found[url.lastPathComponent] = count }
        }
        #expect(found == allowed, "found \(found)")
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
