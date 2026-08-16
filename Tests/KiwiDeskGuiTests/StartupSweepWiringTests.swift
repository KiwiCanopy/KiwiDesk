import Foundation
import Testing

/// The startup sweep's WIRING — the three hunks no behavior suite
/// can red on, split out of `BootPhaseWiringTests` when that file
/// crossed the 350-line ceiling (tests.md ▸ split suites early).
///
/// They belong together: `StartupSweepTests` drives the sweep's
/// scheduled task directly and `StartupWarmupSkipTests` drives the
/// funnel it reconciles through, so both stay green while the boot
/// tail stops scheduling the sweep at all, or while the sweep's
/// own closure loses the per-chunk fold it runs inside.
///
/// Known limits, stated rather than denied (the #635 practice):
/// these are substring and brace-anchored needles over
/// comment-stripped source, so a call moved behind a condition
/// that never holds still matches. Deletion and relocation — the
/// failure modes this class of wiring actually ships — are what
/// they red on.
@Suite("Startup sweep wiring (#662/#836)")
struct StartupSweepWiringTests {
    private func source(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(path)
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // Fail-shut on the scan itself: an empty read passes every
        // needle below for having found nothing.
        try #require(!text.isEmpty)
        return text
    }

    private var bootPath: String {
        "Sources/KiwiDeskCore/App/KiwiCore+Boot.swift"
    }

    /// The link `StartupSweepTests` and `StartupWarmupSkipTests`
    /// each name as the one they cannot reach, carried as prose
    /// in accessibility.md until now. It stopped being merely
    /// unpinned when #836 made a second promise rest on it: the
    /// boot's window-rule write no longer reconciles every app,
    /// on the stated ground that the sweep does the same two
    /// loops chunked one second later. Drop this call and both
    /// the #662 warmup skip and #836's skip heal nothing, with
    /// every behavior suite green — each schedules the sweep
    /// itself.
    @Test("the boot tail schedules the startup sweep")
    func tailSchedulesTheStartupSweep() throws {
        let text = try source(bootPath)
        // Matched to the function's OWN closing brace (a `}` at
        // its declaration indent), following `theFoldDoesNotArm`:
        // a character-budgeted needle overshoots into whatever
        // follows, so the call MOVED out of the tail — which is
        // the regression, since a sweep scheduled from somewhere
        // that does not always run heals nothing — would still
        // match.
        let tail = #"func finishBoot\(\)[\s\S]{0,4000}?\n    \}"#
        let found = try #require(
            text.range(of: tail, options: .regularExpression)
        )
        #expect(
            String(text[found])
                .contains("scheduleStartupSweep()"),
            """
            The boot tail no longer schedules the startup sweep \
            — the #662 warmup skip and #836's window-rule skip \
            both rest on it, and both silently heal nothing \
            without it.
            """
        )
    }

    /// The sweep's per-chunk fold and its deferral drain: both are
    /// one-line decisions inside a closure, and both are invisible
    /// to every behavior suite (the sweep is driven through a real
    /// pass, which no test builds).
    @Test("the sweep folds per chunk and drains its deferrals")
    func sweepFoldsAndDrains() throws {
        let text = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        // Both halves anchored to their OWN function's closing
        // brace, like `theFoldDoesNotArm`. File-scoped needles
        // were defeatable: `driveChunkedPass` is a shared driver
        // by design, so a SECOND chunked pass landing in this
        // file satisfied the fold needle with the sweep's own
        // fold removed, and `drainDeferredBootApps()` appears in
        // the boot tail too (guard-prover, 2026-08-13).
        let schedule =
            #"func scheduleStartupSweep\(\)[\s\S]{0,1600}?\n    \}"#
        let scheduleBody = String(
            text[
                try #require(
                    text.range(
                        of: schedule,
                        options: .regularExpression
                    )
                )
            ]
        )
        #expect(
            scheduleBody.contains("onChunk:"),
            """
            The startup sweep no longer folds per chunk — it
            holds defersEventRetiles for its whole span while
            the mark already says ready, so a window created
            seconds after boot stays untiled.
            """
        )
        let finish =
            #"func finishStartupSweep\([\s\S]{0,1600}?\n    \}"#
        let finishBody = String(
            text[
                try #require(
                    text.range(
                        of: finish,
                        options: .regularExpression
                    )
                )
            ]
        )
        #expect(
            finishBody.contains("drainDeferredBootApps()"),
            """
            The sweep's epilogue no longer drains the deferred
            apps — the sweep budgets too, so one it cut short
            is abandoned rather than completed.
            """
        )
    }

    /// The fold retiles per chunk and arms NOTHING: a sweep over
    /// a hundred apps would otherwise arm the z-order restore
    /// dozens of times, and in track mode each arm drains a
    /// verified raise sequence holding the mouse warp — seconds
    /// after the mark went bright (architect review,
    /// 2026-08-12). The single arm belongs to the epilogue.
    @Test("the sweep's fold retiles without arming")
    func theFoldDoesNotArm() throws {
        let text = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        // Matched to the function's OWN closing brace (a `}` at
        // its declaration indent), not to the first one: the
        // non-greedy `?\}` stopped inside any `if` or closure in
        // the body, so an arm placed after one escaped the needle
        // and the suite passed with the fold arming
        // (guard-prover, 2026-08-12).
        let fold =
            #"func foldSweepChunk\(\)[\s\S]{0,600}?\n    \}"#
        let found = try #require(
            text.range(of: fold, options: .regularExpression)
        )
        let foldBody = String(text[found])
        #expect(foldBody.contains("retile()"))
        #expect(
            !foldBody.contains(
                "scheduleTrackZOrderRestoreIfOverflowing"
            ),
            """
            The sweep's per-chunk fold arms the z-order restore \
            again — dozens of arms per sweep, each one a \
            verified raise sequence that holds the mouse warp \
            for its span. state-and-layout.md ▸ Arm narrowly.
            """
        )
    }
}
