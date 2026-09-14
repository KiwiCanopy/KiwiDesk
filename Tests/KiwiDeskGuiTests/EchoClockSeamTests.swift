import Foundation
import Testing

/// The frame applier's echo grace is measured on an injected
/// clock, and every core a suite builds freezes it (#1456) —
/// tests.md ▸ a test that reads an age-bounded ledger pins the
/// clock. `TravelerRehomeConsumerTests` redded on CI when a
/// starved runner put more than the 1 s grace between a retile's
/// stamp and the read that asked for it.
///
/// Two clauses, the `MouseButtonSeamGuardTests` shape: the host
/// clock is read in ONE home — `FrameApplier.clock`'s default —
/// so a ledger cannot grow a second uptime read beside it; and
/// both `makeTestCore` twins pin the freeze, since deleting it
/// from both is invisible to the twins-identical scan and green
/// on every fast run, which is the run the defect hides in.
/// Residue: each needle is one spelling; a pin re-written
/// equivalently (`{ 0.0 }`) reads as missing, fail-closed.
@Suite("The echo grace runs on an injected clock")
struct EchoClockSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("the applier reads the host clock in one home")
    func uptimeIsReadOnceBehindTheSeam() throws {
        let file = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Tiling/FrameApplier.swift"
        )
        let source = try SourceScan.strippedSource(at: file)
        let reads = source.occurrences(of: "systemUptime")
        #expect(reads == 1, "FrameApplier reads uptime \(reads)×")
        // The one read IS the seam's default, not a ledger's own.
        #expect(
            source.contains(
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
