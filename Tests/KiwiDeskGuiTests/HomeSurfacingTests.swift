import Foundation
import Testing

@testable import KiwiDesk

/// The Home shell's surfacing branches and one-line wiring
/// decisions (#678 turn 9), pinned by needles on the USE sites
/// — the Monitors lesson, three times paid for: a surfacing
/// gate ends in an `if` inside a `body`, and every other guard
/// passes whether or not that `if` was ever written. Comments
/// are stripped (a comment quoting a key must not stand in for
/// a call site) and whitespace squashed, and each needle names
/// the branch TOGETHER with what it draws or decides.
///
/// Stated limit: these are existence pins, not behavior — the
/// behavior halves live in `HomeCardOrderTests`,
/// `HomeCardContentTests` and `SettingsModeNavigationTests`.
/// What only these can see is a branch or a wiring line being
/// deleted whole with the suite green
/// (`ZOrderSequenceWiringTests` is the precedent).
@Suite("Home surfacing branches")
struct HomeSurfacingTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// file (under Sources/KiwiDesk) → needles that must
    /// survive in its comment-stripped, whitespace-squashed
    /// source.
    private static let needles: [String: [String]] = [
        "Settings/SettingsView.swift": [
            // Home mounts exactly when no area is pushed.
            "ifselection==nil{HomeScreen(model:model)",
            // Escape pops an area back to Home.
            ".onExitCommand{ifselection!=nil{selection=nil}}",
            // A link into a Power-User-only area switches the mode
            // before landing.
            "ensureModeAdmits(destination)selection=destination",
        ],
        "Settings/SettingsView+Reveal.swift": [
            // A search hit into a Power-User-only area switches the
            // mode before landing.
            "ensureModeAdmits(resolved.destination)"
                + "model.destination=resolved.destination"
        ],
        "Settings/SettingsHeaderBar.swift": [
            // The pushed form draws the back chip, the Home
            // form the identity.
            "ifletdestination{backChipText(destination.title)",
            // The unsaved count surfaces only while the draft
            // has changes.
            "ifmodel.draftChangeCount>0{unsavedChip}",
        ],
        "Settings/HomeScreen.swift": [
            // The 14c banner is drawn, not merely computed.
            "iffirstRunVisible{HomeFirstRunBanner("
        ],
        "Settings/HomeCard.swift": [
            // The conflict shout is drawn on the card.
            "ifletshout{shoutBadge(shout)}",
            // A preview card DRAWS its preview — the needle
            // runs through the branch body, so a consult whose
            // binding goes unrendered fails it (re-review
            // 2026-08-04: the consult-only form passed with
            // the body emptied).
            "ifletpreview=HomeCardPreview.preview("
                + "for:destination,model:model){preview}",
        ],
        "Settings/SettingsModel+EditTarget.swift": [
            // A dirty draft reaching a clean transition
            // retires the first-run banner (through the
            // injected-domain seam).
            "ifisDirty{"
                + "HomeFirstRunState.retire(firstRunDefaults)}"
        ],
        "Settings/SettingsWindowController.swift": [
            // Home is the entry point on every open.
            "model.destination=nil"
        ],
        "Settings/HomeFirstRunBanner.swift": [
            // Dismiss retires permanently and unmounts.
            "HomeFirstRunState.retire(model.firstRunDefaults)"
                + "visible=false"
        ],
        "AppDelegate+Onboarding.swift": [
            // The tour's close seeds the banner beside the
            // discovery flag.
            "OnboardingDiscovery.markShown()"
                + "HomeFirstRunState.seed()"
        ],
        "AppDelegate.swift": [
            // "Show me around" reaches the real replay.
            "created.setShowTour{[weakself]in"
                + "self?.replayOnboardingTour()}"
        ],
    ]

    @Test("every surfacing branch is drawn where it decides")
    func branchesAreDrawn() throws {
        for (path, wanted) in Self.needles {
            let url = Self.root
                .appendingPathComponent("Sources/KiwiDesk")
                .appendingPathComponent(path)
            let raw = try String(
                contentsOf: url,
                encoding: .utf8
            )
            #expect(!raw.isEmpty)
            let squashed = SourceScan.stripComments(raw)
                .split(whereSeparator: \.isWhitespace)
                .joined()
            for needle in wanted {
                #expect(
                    squashed.contains(needle),
                    Comment(
                        rawValue:
                            "\(path) lost its branch or wiring: "
                            + needle
                    )
                )
            }
        }
    }
}
