import Foundation
import Testing

/// The frame applier's echo grace is measured on an injected
/// clock, and every core a suite builds freezes it (#1456) —
/// tests.md ▸ a test that reads an age-bounded ledger pins the
/// clock. `TravelerRehomeConsumerTests` redded on CI when a
/// starved runner put more than the grace between a retile's
/// stamp and the read that asked for it.
///
/// Two clauses, the `MouseButtonSeamGuardTests` shape. The host
/// uptime is read only where a closure seam DEFAULTS to it —
/// `FrameApplier.clock`, `ZOrderDrain.now`'s and
/// `TeardownRestack.now`'s live wiring — never inside a ledger,
/// so a new bound in either tree reds here until it takes a
/// seam of its own; counted per file, since a total stays green
/// when a read migrates between homes. And both `makeTestCore`
/// twins pin the freeze, since deleting it from both is
/// invisible to the twins-identical scan and green on every fast
/// run, which is the run the defect hides in.
///
/// Residue, both clauses one spelling each: a ledger re-growing
/// its own clock as `Date()`, `CACurrentMediaTime()` or
/// `DispatchTime.now()` is not this needle's — the `Date`-keyed
/// handler ledgers take `now:` per call and are held by their
/// own suites — and a pin re-written equivalently (`{ 0.0 }`)
/// reads as missing, fail-closed.
@Suite("The echo grace runs on an injected clock")
struct EchoClockSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]

    /// Every file that may read the host uptime, with its count:
    /// each site is a closure seam's live default.
    private static let allowed: [String: Int] = [
        "FrameApplier.swift": 1,
        "KiwiCore+ZOrderFloats.swift": 1,
        "KiwiCore+TeardownRaise.swift": 2,
    ]

    @Test("the host uptime is read only as a seam's default")
    func uptimeIsReadOnlyBehindASeam() throws {
        var counts: [String: Int] = [:]
        for tree in Self.productionTrees {
            for file in try SourceScan.swiftSources(under: tree) {
                let hits = try SourceScan.strippedSource(at: file)
                    .occurrences(of: "systemUptime")
                if hits > 0 {
                    counts[file.lastPathComponent, default: 0] += hits
                }
            }
        }
        for (file, expected) in Self.allowed {
            let found = counts[file] ?? 0
            #expect(
                counts[file] == expected,
                "\(file) reads uptime \(found)× (pinned \(expected))"
            )
        }
        let strays = counts.keys.filter { Self.allowed[$0] == nil }
        #expect(
            strays.isEmpty,
            "uptime read outside a seam default: \(strays.sorted())"
        )
        // The applier's one read IS the seam's default.
        let applier = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Tiling/FrameApplier.swift"
        )
        #expect(
            try SourceScan.strippedSource(at: applier).contains(
                "var clock: @Sendable () -> TimeInterval = {"
            )
        )
    }

    @Test("makeTestCore freezes the clock in both twins")
    func testCoreFreezesTheClock() throws {
        let twins = ["KiwiDeskCoreTests", "KiwiDeskGuiTests"]
            .map {
                Self.root.appendingPathComponent(
                    "Tests/\($0)/TestCore.swift"
                )
            }
        for twin in twins {
            let source = try SourceScan.strippedSource(at: twin)
            let target = twin.deletingLastPathComponent()
                .lastPathComponent
            let pins = source.occurrences(
                of: "core.tiler.applier.clock = { 0 }"
            )
            #expect(pins == 1, "\(target) pins the clock \(pins)×")
        }
    }
}
