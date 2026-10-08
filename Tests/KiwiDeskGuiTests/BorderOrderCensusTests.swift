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
        "BorderManager+SkyLight.swift": (
            2,
            "the WindowServer reorder and unhide events"
        ),
        "BorderManager+DeadEnd.swift": (1, "the transient dead-end ring"),
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
