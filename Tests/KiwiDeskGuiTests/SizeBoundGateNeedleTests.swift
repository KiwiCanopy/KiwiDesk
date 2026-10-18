import Foundation
import Testing

/// The observe gate's PRODUCTION branch — a decision no unit
/// test reaches (architect re-review, 2026-08-18): the
/// behavioral fixtures replace `animation.apply`, so no
/// `didRecentlySetFrame` stamp is written on the animated path
/// and `echoGraceOverride` carries the tests instead. Replace
/// the production default with `false` and the tree stays green while
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

    @Test("An instant layout ask schedules the settle probe")
    func instantAskProbeIsWired() throws {
        // An instant write never settles, so its probe rides
        // `onInstantLayoutAsk` (#2187) — a production wire no
        // unit test reaches, and unwired a raw mid-resize echo
        // confirms a false bound.
        let boot = try SourceScan.functionBody(
            of: "bootstrapCoreServices",
            in: "KiwiCore+Bootstrap.swift",
            under: "App"
        )
        guard let hook = boot.range(of: "tiler.onInstantLayoutAsk = {")
        else {
            Issue.record("onInstantLayoutAsk is not wired")
            return
        }
        #expect(
            boot[hook.upperBound...].prefix(120)
                .contains("scheduleSizeBoundProbe(id)")
        )
        // Fired after the ask is recorded, which the probe's
        // `wantsAnswerProbe` gate reads.
        let issue = try SourceScan.functionBody(
            of: "issueLayoutFrame",
            in: "TilingEngine+Issue.swift",
            under: "Tiling"
        )
        let ask = issue.range(of: "boundLearner.recordAsk(")
        let fire = issue.range(of: "onInstantLayoutAsk(id)")
        #expect(ask != nil && fire != nil)
        if let ask, let fire {
            #expect(ask.upperBound < fire.lowerBound)
        }
    }

    @Test("Each apply stamps at enqueue AND after the set")
    func applyStampsTwice() throws {
        // The enqueue stamp closes #1254 (the echo can precede a
        // post-set stamp — `FrameApplierStampTests`); the post-set
        // stamp keeps the grace running from the set's RETURN for
        // a queue that runs late. A reader deduplicating the pair
        // narrows the grace to 1 s from enqueue, and no behavioral
        // fixture writes a stamp to red on it.
        for function in ["apply", "applyInstant"] {
            let source = try SourceScan.functionBody(
                of: function,
                in: "FrameApplier.swift",
                under: "Tiling"
            )
            let stamps =
                source.components(
                    separatedBy: "recent.record(id, now: clock())"
                ).count - 1
            #expect(stamps == 2, "\(function) stamps \(stamps)×")
        }
    }
}
