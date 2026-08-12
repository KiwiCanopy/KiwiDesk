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

    @Test("the scan publishes its first count")
    func scanPublishesItsFirstCount() throws {
        let text = try source(bootPath)
        let pattern =
            #"boot\.publish\([\s\S]{0,80}?\.scanning"#
        #expect(
            text.range(of: pattern, options: .regularExpression)
                != nil,
            """
            KiwiCore+Boot no longer publishes a scanning phase — \
            the quick menu opens with no status row and the mark \
            never dims, for the whole boot.
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

    @Test("the GUI reads the phase both ways")
    func guiReadsThePhaseBothWays() throws {
        let text = try source("Sources/KiwiDesk/AppDelegate.swift")
        // The pull, for the count the menu draws on open …
        let provider =
            #"bootPhaseProvider\s*=\s*\{[\s\S]{0,120}?"#
            + #"core\.bootPhase"#
        #expect(
            text.range(of: provider, options: .regularExpression)
                != nil,
            """
            AppDelegate no longer wires bootPhaseProvider to \
            core.bootPhase — the quick menu's status row reads a \
            hardcoded .ready and never appears.
            """
        )
        // … and the push, for the icon and the tour.
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
