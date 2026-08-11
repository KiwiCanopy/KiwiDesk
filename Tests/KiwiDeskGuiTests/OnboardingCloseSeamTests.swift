import Foundation
import Testing

@testable import KiwiDesk

/// The tour's close seam and its one voluntary entry, pinned by
/// needles on the USE sites — the same shape as
/// `HomeSurfacingTests`, split out of it at the §2.1 ceiling.
///
/// They belong together as a subject: both are `AppDelegate`
/// wiring that Home depends on, and both are one-line decisions
/// whose deletion reds nothing else. The seam's history is why
/// the needles name their CONDITION and not only the calls
/// inside it — an earlier cut watched the calls while the
/// condition above them was a hand-written list of terminal
/// steps, so reordering the steps would have killed Home's
/// first-run banner with the whole suite green.
@Suite("Onboarding close seam")
struct OnboardingCloseSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    private static let needles: [String: [String]] = [
        "AppDelegate+Onboarding.swift": [
            // The tour's close seeds the banner beside the
            // discovery flag — needled WITH its condition
            // (#678 Phase 4 pass 11).
            //
            // The earlier cut matched only the two calls, and
            // the condition above them was a hand-written list
            // of terminal step cases. Renaming or reordering the
            // steps would have left that list matching nothing,
            // the banner permanently dead, and this needle
            // green — it could not see the half that decides.
            // Now the seam asks the model one question, and the
            // needle reads the question.
            "ifonboardingModel.reachedEnd{"
                + "OnboardingDiscovery.markShown()"
                + "HomeFirstRunState.seed(.standard)"
                + "showMenuBarCoachMark()}",
            // …and the flag is CONSUMED, so it scopes to this
            // presentation rather than to a model that outlives
            // every window. Deleting the line reds nothing
            // otherwise, and re-fires all three effects on the
            // quick menu's reopen (code review, 2026-08-11).
            "onboardingModel.clearReachedEnd()",
        ],
        "AppDelegate.swift": [
            // "Show me around" reaches the real replay.
            "created.setShowTour{[weakself]in"
                + "self?.replayOnboardingTour()}"
        ],
    ]

    @Test("the close seam and the replay entry are wired")
    func seamsAreWired() throws {
        for (path, wanted) in Self.needles {
            let url = Self.root
                .appendingPathComponent("Sources/KiwiDesk")
                .appendingPathComponent(path)
            let raw = try String(contentsOf: url, encoding: .utf8)
            #expect(!raw.isEmpty)
            let squashed = SourceScan.stripComments(raw)
                .split(whereSeparator: \.isWhitespace)
                .joined()
            for needle in wanted {
                #expect(
                    squashed.contains(needle),
                    Comment(
                        rawValue:
                            "\(path) no longer carries "
                            + "`\(needle)` — the wiring it names "
                            + "was deleted or reshaped"
                    )
                )
            }
        }
        #expect(Self.needles.count >= 2)
    }
}
