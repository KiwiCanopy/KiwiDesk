import Foundation
import Sparkle
import Testing

@testable import KiwiDesk

/// The install-and-restart prompt comes forward (#1011).
///
/// One of three suites over this seam, cut where the production
/// code is: `UpdaterSeamGuardTests` counts how many of each
/// object exist, `UpdatePromptWiringTests` holds what the seam
/// HANDS Sparkle, and this one holds what the driver and its
/// policy DECLARE. It reads `UpdatePromptDriver.swift` only, so
/// no needle here can be satisfied by the seam file.
///
/// Source scans for the parts that cannot reach a unit test:
/// the override puts a real window on screen out of
/// `Sparkle.framework`, and `NSApp.activate` is the machine.
/// The policy's own answer is NOT one of those — it is a pure
/// predicate on an object that touches nothing, so it is asserted
/// by CALLING it, and the selectors Sparkle looks for are
/// asserted through the ObjC runtime rather than through a
/// spelling.
///
/// **A source needle reads a spelling, never a value or a
/// control path**, and the limit is stated rather than left to
/// be discovered. Two shapes pass while the behaviour is gone:
/// a call placed behind a never-true condition keeps every
/// needle's string, and a body whose words include the answer
/// need not return it. `guard-prover` found the second one for
/// real — `contains("false")` over a body returning `!allows` —
/// which is why the policy's answer is no longer scanned at all
/// but CALLED. The first has no answer inside a scan: closing it
/// would mean running Sparkle. Where a fact can be asserted by
/// calling it, prefer that over adding a needle here.
///
@Suite("The install prompt comes forward (#1011)")
struct UpdatePromptFocusTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    /// One file: this suite reads what the driver and its policy
    /// DECLARE. What the seam HANDS Sparkle is
    /// `UpdatePromptWiringTests`, which reads the other one and
    /// cannot be satisfied by this one.
    private static let prompt = "UpdatePromptDriver.swift"

    private static func promptSource() throws -> String {
        try SourceScan.strippedSource(
            at:
                root
                .appendingPathComponent("Sources/KiwiDesk/Updates")
                .appendingPathComponent(prompt)
        )
    }

    @Test("the override brings the app forward and defers to Sparkle")
    func overrideComesForward() throws {
        let text = try Self.promptSource()
        guard
            let driver = SourceScan.declarationBody(
                after: "final class UpdatePromptDriver",
                in: text
            )
        else {
            Issue.record(
                "no UpdatePromptDriver class in \(Self.prompt)"
            )
            return
        }
        guard
            let override = SourceScan.declarationBody(
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

    /// Activating is not enough on its own if the window can be
    /// parked (#1011). Sparkle offers the status window a
    /// minimize button unless its delegate refuses, the window
    /// the user parks during the download IS the one that
    /// becomes the prompt, and activating a process
    /// deminiaturizes nothing — so a minimized prompt would wait
    /// in a Dock KiwiDesk has no icon in.
    ///
    /// The same policy carries the modal-alert half, so the
    /// obligation the rule states — a window the user must
    /// ANSWER comes forward — is met for Sparkle's error and
    /// acknowledgement alerts too, not only for the prompt.
    @Test("the prompt cannot be parked out of the activation's reach")
    func promptStaysReachable() throws {
        let declared = try Self.promptSource()
        guard
            let policy = SourceScan.declarationBody(
                after: "final class UpdatePromptPolicy",
                in: declared
            )
        else {
            Issue.record(
                "no UpdatePromptPolicy class in \(Self.prompt)"
            )
            return
        }
        guard
            let alert = SourceScan.declarationBody(
                after: "func standardUserDriverWillShowModalAlert",
                in: policy
            )
        else {
            Issue.record("UpdatePromptPolicy lost its alert answer")
            return
        }
        #expect(
            alert.contains("NSApp.activate(ignoringOtherApps: true)"),
            "Sparkle's modal alerts must come forward too"
        )
    }

    /// The two answers Sparkle actually looks for, asserted
    /// through the ObjC runtime rather than through a spelling.
    ///
    /// **Both are OPTIONAL protocol requirements**, which is the
    /// whole reason this test exists beside the scan above. Rename
    /// either method and nothing refuses to compile: Sparkle's
    /// `respondsToSelector:` simply answers NO, it restores the
    /// minimize button or skips the activation, and #1011 is back
    /// with every source needle still green. `#selector` on the
    /// protocol member is compiler-checked, so a Sparkle upgrade
    /// that renames the requirement reds here too.
    ///
    /// It reaches nothing: `UpdatePromptPolicy()` is a bare
    /// `NSObject` and the minimize answer is a pure predicate.
    /// `standardUserDriverWillShowModalAlert` is deliberately NOT
    /// called — its body is `NSApp.activate`, and `NSApp` is nil
    /// in a test process — so the scan above is what holds its
    /// body and this holds that Sparkle can find it.
    @MainActor
    @Test("the policy answers the selectors Sparkle asks for")
    func policyAnswersSparkle() {
        let policy = UpdatePromptPolicy()
        #expect(
            policy.responds(
                to: #selector(
                    SPUStandardUserDriverDelegate
                        .standardUserDriverAllowsMinimizableStatusWindow
                )
            ),
            """
            Sparkle asks for this by selector and falls back to \
            a minimizable window when nobody answers
            """
        )
        #expect(
            policy.standardUserDriverAllowsMinimizableStatusWindow()
                == false,
            """
            the status window must refuse the minimize button: \
            activation cannot recover a parked one, and there is \
            no Dock icon to recover it from
            """
        )
        #expect(
            policy.responds(
                to: #selector(
                    SPUStandardUserDriverDelegate
                        .standardUserDriverWillShowModalAlert
                )
            ),
            "Sparkle's modal alerts must reach the activation"
        )
    }
}
