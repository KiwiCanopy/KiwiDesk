import Foundation
import Testing

/// A ring's re-stack is AppKit's order, a synchronous WindowServer
/// round trip that stalls a Space switch under GPU load (#1925,
/// #1962), so who may order a ring is a census, not prose: a new
/// trigger is a new round trip and owes its ruling here. And the
/// SkyLight orders WindowServer ignores for an AppKit panel stay
/// unresolved in both trees, so the no-op cannot return as an
/// optimisation (borders.md).
@Suite("Border ring order census (#1962)")
struct BorderOrderCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → its `order(relativeTo:` call sites and why each may
    /// order a ring.
    static let allowed: [String: (count: Int, why: String)] = [
        "BorderOverlay.swift": (
            2,
            "the forwarding order and the unhide's restore of "
                + "visibility"
        ),
        "BorderManager+Sync.swift": (
            1,
            "sync, gated by `ordersOverlay`: needsOrder, a settle "
                + "pass or no WindowServer stream"
        ),
        "BorderManager+WindowServer.swift": (
            1,
            "the watch's restack phase: the WindowServer reorder "
                + "and unhide events (#2275)"
        ),
        "BorderManager+DeadEnd.swift": (1, "the transient dead-end ring"),
        "BorderManager.swift": (
            1,
            "`restack`, the anchor's ring once the float-tier "
                + "raise lands (#2284)"
        ),
    ]

    @Test("only the ruled sites order a ring")
    func orderSitesAreCensused() throws {
        let sites = try SourceScan.identifierSites(
            of: "order(relativeTo:",
            under: Self.root.appendingPathComponent("Sources/KiwiDeskCore")
        )
        var counts: [String: Int] = [:]
        for site in sites {
            counts[site.file.lastPathComponent, default: 0] += 1
        }
        #expect(
            counts == Self.allowed.mapValues(\.count),
            "found \(sites.map(\.site))"
        )
    }

    /// A sticky mark's stack is the same round trip (#2026): its
    /// callers are the sync behind `ordersOverlay` and the
    /// WindowServer reorder events' `reassert`, beside the one
    /// definition in the overlay.
    @Test("only the ruled sites stack a sticky mark")
    func markOrderSitesAreCensused() throws {
        let sites = try SourceScan.identifierSites(
            of: "order()",
            under: Self.root.appendingPathComponent("Sources/KiwiDeskCore")
        )
        #expect(
            sites.map(\.file.lastPathComponent).sorted() == [
                "StickyMarkManager.swift", "StickyMarkManager.swift",
                "StickyMarkOverlay.swift",
            ],
            "found \(sites.map(\.site))"
        )
    }

    /// A float's veil is one more order per float on the switch
    /// path (#2103 ruling 3): its callers are the manager's sync,
    /// gated by the ring's own `ordersOverlay`, and its restack
    /// after the float's reorder event, which the watch delivers
    /// after the mark's and the ring's, so the veil ends above
    /// both.
    @Test("only the ruled sites stack a float veil")
    func floatVeilOrderSitesAreCensused() throws {
        let sites = try SourceScan.identifierSites(
            of: "order(above:",
            under: Self.root.appendingPathComponent("Sources/KiwiDeskCore")
        )
        #expect(
            sites.map(\.file.lastPathComponent).sorted() == [
                "FloatDimManager.swift", "FloatDimManager.swift",
            ],
            "found \(sites.map(\.site))"
        )
        let wiring = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+WindowServer.swift"
            )
        ).filter { !$0.isWhitespace }
        #expect(
            wiring.contains(
                "restack:{[weakself]idinself?.floatDims.restack(id)}"
            )
        )
        let floats = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+VisionFloats.swift"
            )
        )
        #expect(!floats.contains("shelfStandsDown("))
    }

    /// A KiwiVision plate's stack is the same round trip, one per
    /// screen (#2103): its callers are the sync, gated by the
    /// ring's own `ordersOverlay`, and the target's restack after
    /// its reorder event, beside the one definition in the plate.
    @Test("only the ruled sites stack a KiwiVision plate")
    func plateOrderSitesAreCensused() throws {
        let sites = try SourceScan.identifierSites(
            of: "order(below:",
            under: Self.root.appendingPathComponent("Sources/KiwiDeskCore")
        )
        #expect(
            sites.map(\.file.lastPathComponent).sorted() == [
                "VisionManager.swift", "VisionManager.swift",
            ],
            "found \(sites.map(\.site))"
        )
        // The plate restacks AFTER the ring's own order — the
        // watch's consumer order, held by `WindowServerWatchTests`
        // ▸ `phaseOrder`, or the ring lands under the plate — and
        // its restack hook is the one the core connects.
        let wiring = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+WindowServer.swift"
            )
        ).filter { !$0.isWhitespace }
        #expect(
            wiring.contains(
                "restack:{[weakself]idinself?.visionTargetRestacked(id)}"
            )
        )
        // The stand-down is the shelf's verdict, filed by the one
        // bar refresh, never a read of the plate's own.
        let shelf = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Shelf.swift"
            )
        )
        #expect(shelf.contains("noteVisionStandDown(standingDown)"))
        let vision = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Vision.swift"
            )
        )
        #expect(!vision.contains("shelfStandsDown("))
    }

    /// The #1959 hold is armed in one door, the switch's own
    /// retile, which knows whether the switch un-parks its anchor;
    /// a second switch path arming its own would hold a ring with
    /// nothing to arrive (borders.md).
    @Test("one door arms the ring's arrival hold")
    func arrivalHoldHasOneDoor() throws {
        let sites = try SourceScan.identifierSites(
            of: "holdArrival(of:",
            under: Self.root.appendingPathComponent("Sources/KiwiDeskCore")
        )
        #expect(
            sites.map(\.file.lastPathComponent)
                == ["KiwiCore+SpaceTransition.swift"],
            "found \(sites.map(\.site))"
        )
    }

    @Test("no SkyLight window order is resolved")
    func noSkyLightOrder() throws {
        var files: [URL] = []
        for tree in ["Sources", "Tests"] {
            files += try SourceScan.swiftSources(
                under: Self.root.appendingPathComponent(tree)
            )
        }
        #expect(files.count > 500)
        var hits: [String] = []
        for file in files
        where file.lastPathComponent != "BorderOrderCensusTests.swift" {
            let text = try SourceScan.strippedSource(at: file)
            for name in ["SLSTransactionOrderWindow", "SLSOrderWindow"]
            where text.contains(name) {
                hits.append("\(file.lastPathComponent): \(name)")
            }
        }
        #expect(hits.isEmpty, "found \(hits)")
    }
}
