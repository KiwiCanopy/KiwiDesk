import Foundation
import Testing

/// The install-and-restart prompt comes forward (#1011).
///
/// Split from `UpdaterSeamGuardTests` rather than added to it —
/// that suite pins how many of each object exist, this one pins
/// what the one driver DOES and that Sparkle is actually shown
/// through it. Two facts, and the file was one addition from
/// §2.1's sweet spot either way.
///
/// Source scans because neither half reaches a unit test: the
/// override puts a real window on screen out of
/// `Sparkle.framework`, and `NSApp.activate` is the machine.
@Suite("The install prompt comes forward (#1011)")
struct UpdatePromptFocusTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let seam = "AppUpdater.swift"

    private static func seamSource() throws -> String {
        try SourceScan.strippedSource(
            at:
                root
                .appendingPathComponent("Sources/KiwiDesk/Updates")
                .appendingPathComponent(seam)
        )
    }

    /// The balanced `{ … }` that follows the first `declaration`
    /// in `text`, or nil when it is absent or unbalanced.
    ///
    /// Composable on purpose: handed a class body it searches
    /// inside that body, which is how the override below is
    /// pinned to the driver Sparkle uses rather than to the
    /// first one spelled in the file. A `guard-prover` probe
    /// took exactly that route — a decoy class above the live
    /// one, carrying the right body, over a gutted override —
    /// and an unscoped scan stayed green on it.
    private static func body(
        after declaration: String,
        in text: String
    ) -> String? {
        guard let declared = text.range(of: declaration)
        else { return nil }
        let characters = Array(text)
        let offset = text.distance(
            from: text.startIndex,
            to: declared.lowerBound
        )
        guard
            var cursor = characters[offset...]
                .firstIndex(of: "{")
        else { return nil }
        return SourceScan.balanced(
            characters,
            from: &cursor,
            open: "{",
            close: "}"
        )
    }

    @Test("the override activates before Sparkle shows the prompt")
    func overrideComesForward() throws {
        let text = try Self.seamSource()
        guard
            let driver = Self.body(
                after: "final class UpdatePromptDriver",
                in: text
            )
        else {
            Issue.record("no UpdatePromptDriver class in \(Self.seam)")
            return
        }
        guard
            let override = Self.body(
                after:
                    "override func showReadyToInstallAndRelaunch",
                in: driver
            )
        else {
            Issue.record(
                """
                UpdatePromptDriver no longer overrides \
                showReadyToInstallAndRelaunch
                """
            )
            return
        }
        #expect(
            override.contains(
                "NSApp.activate(ignoringOtherApps: true)"
            ),
            .init(
                rawValue: "the ready-to-install override must "
                    + "bring the app forward: a menu-bar app has "
                    + "no Dock tile for Sparkle's "
                    + "requestUserAttention to bounce, so an "
                    + "unactivated prompt is invisible. Body: "
                    + override
            )
        )
        #expect(
            override.contains(
                "super.showReadyToInstallAndRelaunch("
            ),
            "the override must still let Sparkle show the prompt"
        )
    }

    /// The override only helps if Sparkle shows its UI THROUGH
    /// it. Pinned because a `guard-prover` probe rewired
    /// `userDriver:` to a fresh stock `SPUStandardUserDriver`
    /// and every count in `UpdaterSeamGuardTests` stayed at one:
    /// `UpdatePromptDriver` was still built, still stored, still
    /// overriding — and dead, with #1011 shipped again in full.
    ///
    /// Two needles for that one fact. The stock driver is
    /// SUBCLASSED here and never constructed, so any
    /// `SPUStandardUserDriver(` in the production trees is the
    /// rewire; and the driver named at the `userDriver:`
    /// argument is the property the override lives on.
    @Test("Sparkle shows its UI through the overriding driver")
    func sparkleUsesTheOverridingDriver() throws {
        let stock = try SourceScan.identifierSites(
            of: "SPUStandardUserDriver(",
            under: Self.root
                .appendingPathComponent("Sources/KiwiDesk")
        )
        #expect(
            stock.isEmpty,
            .init(
                rawValue: "Sparkle's stock user driver is "
                    + "subclassed, never constructed — a "
                    + "construction is the #1011 override going "
                    + "dead: "
                    + stock.map(\.site).joined(separator: ", ")
            )
        )

        let text = try Self.seamSource()
        #expect(
            text.contains("driver = UpdatePromptDriver("),
            "the stored driver must be the overriding one"
        )
        let characters = Array(text)
        guard let built = text.range(of: "SPUUpdater(") else {
            Issue.record("no SPUUpdater construction in \(Self.seam)")
            return
        }
        var cursor =
            text.distance(
                from: text.startIndex,
                to: built.upperBound
            ) - 1
        guard
            let arguments = SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            )
        else {
            Issue.record("the SPUUpdater arguments are unbalanced")
            return
        }
        #expect(
            arguments.contains("userDriver: driver"),
            .init(
                rawValue: "SPUUpdater must be handed the "
                    + "overriding driver, not another one. "
                    + "Arguments: " + arguments
            )
        )
    }
}
