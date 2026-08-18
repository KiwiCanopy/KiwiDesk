import Foundation
import Testing

/// The observe gate's PRODUCTION branch — a decision no unit
/// test reaches (architect re-review, 2026-08-18): every
/// fixture severs the applier, so the `didRecentlySetFrame`
/// stamp is never written in-suite and `echoGraceOverride`
/// carries the tests instead. Replace the production default
/// with `false` and the whole tree stays green while
/// production learns bounds from un-echoed asks — the false
/// bound `RetileBoundSkipTests.staleEchoDoesNotConfirm` pins
/// only through the seam.
///
/// A presence scan (`OwnPidQueueNeedleTests`' polarity):
/// deleting the default reds; the gate's semantics live in the
/// behavioral suite.
@Suite("Size-bound gate needle (#677)")
struct SizeBoundGateNeedleTests {
    @Test("The gate defaults to the applier's echo grace")
    func gateDefaultsToEchoGrace() throws {
        // Both #677 channels consult `askEchoLikely`, so the
        // production default lives in ITS body now.
        let source = try SourceScan.functionBody(
            of: "askEchoLikely",
            in: "TilingEngine+SizeBounds.swift",
            under: "Tiling"
        )
        #expect(source.contains("echoGraceOverride?(id)"))
        #expect(source.contains("?? didRecentlySetFrame(id)"))
    }

    @Test("The settle probe is wired at bootstrap")
    func settleProbeIsWired() throws {
        // The probe's schedule rides `onWindowSettled` in
        // Bootstrap — a production wire no unit test reaches
        // (the suites call `runSizeBoundProbe` directly), and
        // an unwired probe starves the whole answer channel on
        // a quiet screen (#677 device QA).
        let source = try SourceScan.functionBody(
            of: "bootstrapCoreServices",
            in: "KiwiCore+Bootstrap.swift",
            under: "App"
        )
        #expect(
            source.contains("scheduleSizeBoundProbe(id)")
        )
    }
}
