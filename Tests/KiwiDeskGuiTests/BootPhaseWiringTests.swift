import Foundation
import Testing

/// The boot-readiness DELIVERY path (#802) — the hunks no
/// behavior test can red on.
///
/// `BootPhaseTests` drives `BootRun` and the chunk driver
/// directly, and every GUI suite injects
/// `bootPhaseProvider`/`setBootPhase` by hand, so all of them stay
/// green while the phase never reaches a surface in production:
/// `start()` arms the real machine seams and no test drives it,
/// and `stop()` tears down a live event loop. That is the
/// `scheduleStartupSweep` / `ClickProvenanceWiringTests` class of
/// hole, and these are its needles.
///
/// What each one is for:
/// 1. the scan's first publication — without it the menu opens
///    with no status row for the whole boot, which is the
///    #801 symptom wearing #802's clothes;
/// 2. `.ready` at the end of the tail — without it the mark stays
///    dimmed and Layout stays greyed for the rest of the session;
/// 3. `.idle` in `stop()` — a permission revoke leaves a
///    readiness signal up forever, since `cancelAll()` has just
///    killed the only thing that would publish again;
/// 4. the GUI's two reads (provider + change seam) and the tour's
///    seed, each keyed on its use site.
///
/// Known limits, stated rather than denied (the #635 practice):
/// these are substring needles over comment-stripped source, so a
/// publication moved behind a condition that never holds still
/// matches, and so does one whose argument is wrong. Deletion and
/// relocation — the failure modes this class of wiring actually
/// ships — are what they red on.
@Suite("Boot readiness wiring (#802)")
struct BootPhaseWiringTests {
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

    /// TWO publications, needled apart (guard-prover,
    /// 2026-08-12): one regex over the file matched either site,
    /// so deleting the per-chunk publish alone passed — and that
    /// is the deletion that matters, since it leaves the phase at
    /// `scanning(0, N)` until `.ready` with the menu's count row
    /// and the tour's footer frozen at zero, which is the whole
    /// of #802's live half.
    @Test("start publishes the first count")
    func startPublishesTheFirstCount() throws {
        let text = try source(bootPath)
        let pattern =
            #"beginScan\(\)[\s\S]{0,400}?boot\.publish\("#
            + #"[\s\S]{0,60}?\.scanning"#
        #expect(
            text.range(of: pattern, options: .regularExpression)
                != nil,
            """
            start() no longer publishes the opening count — the \
            quick menu opens with no status row and the mark \
            never dims until the first chunk lands.
            """
        )
    }

    @Test("each chunk publishes its own count")
    func eachChunkPublishesItsCount() throws {
        let text = try source(bootPath)
        let pattern =
            #"onChunk:\s*\{[\s\S]{0,200}?boot\.publish\("#
            + #"[\s\S]{0,120}?progress\.scanned"#
        #expect(
            text.range(of: pattern, options: .regularExpression)
                != nil,
            """
            driveBootScan's onChunk no longer publishes the \
            progress — the count freezes at 0 for the whole boot \
            while every phase suite stays green (they inject \
            their own onChunk).
            """
        )
    }

    @Test("the tail publishes ready")
    func tailPublishesReady() throws {
        let text = try source(bootPath)
        #expect(
            text.contains("boot.publish(.ready)"),
            """
            KiwiCore+Boot no longer publishes .ready — the mark \
            stays dimmed and Layout stays greyed for the rest of \
            the session.
            """
        )
    }

    @Test("stop publishes idle")
    func stopPublishesIdle() throws {
        let text = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        #expect(
            text.contains("boot.publish(.idle)"),
            """
            KiwiCore+Lifecycle's stop() no longer publishes \
            .idle — a permission revoke leaves the starting \
            signal up forever, cancelAll() having killed the \
            chunk continuation that would publish again.
            """
        )
    }

    @Test("the GUI takes the pushed phase, twice over")
    func guiTakesThePushedPhase() throws {
        let text = try source("Sources/KiwiDesk/AppDelegate.swift")
        // ONE push, two consumers: the status item (icon rank, the
        // count row, the greys) and the tour.
        let change =
            #"onBootPhaseChange\s*=\s*\{[\s\S]{0,200}?"#
            + #"setBootPhase"#
        #expect(
            text.range(of: change, options: .regularExpression)
                != nil,
            """
            AppDelegate no longer forwards onBootPhaseChange to \
            the status item — the mark never dims and never \
            returns.
            """
        )
        #expect(
            text.contains("onboardingModel.bootPhase = phase"),
            """
            AppDelegate no longer forwards the phase to the tour \
            — the grant screen claims a finished arrangement \
            mid-scan.
            """
        )
    }

    /// The link `ClickProvenanceWiringTests` lost when the seams
    /// moved to their own file: every seam in `KiwiCore+BootSeams`
    /// is injected by tests, so deleting the CALL leaves that
    /// whole suite green while `stackingOrderProvider`,
    /// `pointerWarp`, `frontmostPIDProvider` and the mouse and
    /// border tees all stay nil in production (code review,
    /// 2026-08-12).
    @Test("start arms the machine seams")
    func startArmsTheMachineSeams() throws {
        let text = try source(bootPath)
        #expect(
            text.contains("armMachineSeams()"),
            """
            KiwiCore+Boot's start() no longer calls
            armMachineSeams() — every machine seam stays nil
            in production and every suite that injects one
            stays green.
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
        let folds =
            #"driveChunkedPass\([\s\S]{0,200}?onChunk:"#
        #expect(
            text.range(of: folds, options: .regularExpression)
                != nil,
            """
            The startup sweep no longer folds per chunk — it
            holds defersEventRetiles for its whole span while
            the mark already says ready, so a window created
            seconds after boot stays untiled.
            """
        )
        #expect(
            text.contains("drainDeferredBootApps()"),
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
        let fold = #"func foldSweepChunk\(\)[\s\S]{0,400}?\}"#
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

    /// A stop mid-boot must not write the session file.
    @Test("stop preserves the session while starting")
    func stopPreservesTheSessionMidBoot() throws {
        let text = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        let pattern =
            #"!boot\.reachedReady[\s\S]{0,200}?"#
            + #"preservingSession: true"#
        #expect(
            text.range(of: pattern, options: .regularExpression)
                != nil,
            """
            stop() no longer preserves the session for a launch
            that never reached ready — a quit or a permission
            revoke mid-scan writes a fraction of the desk over
            the arrangement this launch never restored. Keyed on
            the LATCH: gating on the phase let a SECOND stop
            (quit after a mid-boot revoke) read as "not
            starting" and undo the first one's protection.
            """
        )
    }

    /// The tour's count is a surfacing branch inside a `body`:
    /// the hint expression and the pulse can both be deleted with
    /// `OnboardingGrantPhaseTests` green, because that suite reads
    /// the properties rather than the page they are handed to.
    /// The latch the gate above reads: set by the tail, cleared
    /// by `start()`. Neither assignment is reachable from a test
    /// — `start()` arms the real machine seams — so both are
    /// needled here.
    @Test("the boot tail latches that it reached ready")
    func theTailLatchesReady() throws {
        let text = try source(bootPath)
        #expect(
            text.contains("boot.reachedReady = true"),
            """
            The boot tail no longer latches that it finished, so
            every later stop() preserves the session — a quit
            after a normal session stops saving the arrangement
            at all.
            """
        )
        #expect(
            text.contains("boot.reachedReady = false"),
            """
            start() no longer clears the latch, so a relaunch
            inherits the previous launch's verdict and a stop
            mid-boot writes over the session it should keep.
            """
        )
    }

    @Test("the tour hands its count to the page")
    func tourHandsTheCountToThePage() throws {
        let text = try source(
            "Sources/KiwiDesk/Onboarding/OnboardingView+Grant.swift"
        )
        #expect(
            text.contains("hint: grantHintForPhase"),
            """
            The grant page no longer takes grantHintForPhase —
            the count is derived and never drawn, which every
            other guard passes over.
            """
        )
        #expect(
            text.contains("hintPulses: isArranging"),
            """
            The grant page no longer pulses while arranging —
            the footer count reads as a caption rather than as
            work in flight (owner, 2026-08-12).
            """
        )
    }

    @Test("the tour seeds the phase when it opens")
    func tourSeedsThePhase() throws {
        let text = try source(
            "Sources/KiwiDesk/AppDelegate+Onboarding.swift"
        )
        #expect(
            text.contains("onboardingModel.bootPhase = core.bootPhase"),
            """
            showOnboarding no longer seeds the boot phase — a tour \
            opened mid-boot inherits the model's .ready default, \
            which is the exact claim #802 removed.
            """
        )
    }
}
