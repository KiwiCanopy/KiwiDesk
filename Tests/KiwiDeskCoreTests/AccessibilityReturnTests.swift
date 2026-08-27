import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #958 accessibility-steal return: starting VoiceOver
/// activates `com.apple.universalaccesscontrol`, and when it
/// yields, macOS re-activates the previous REGULAR app —
/// KiwiDesk is an accessory app, so its focused own window is
/// skipped and a clickless foreign focus report lands moments
/// later. The return keeps state focus on the victim; each
/// let-out (click, own-pid fulfilment, expiry, one-shot) is a
/// case below. The device evidence is on the issue.
@Suite("Accessibility-steal return (#958)", .serialized)
@MainActor
struct AccessibilityReturnTests {
    private static let voBundle =
        "com.apple.universalaccesscontrol"

    /// Windows 1 (OUR pid — the victim) and 2 (a foreign
    /// regular app), window 1 focused — the fixture the steal
    /// hits. Window 3 is the panel app's untracked window in
    /// spirit; the arm needs only the seam call.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-a11y-return-\(UUID().uuidString)"
                )
        )
        let own = pid_t(
            ProcessInfo.processInfo.processIdentifier
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: own,
                    appName: "KiwiDesk"
                )
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 99,
                    appName: "Other"
                )
            )
        )
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        return core
    }

    @Test("The misdirected yield is returned to the victim")
    func yieldIsReturned() {
        let core = makeCore()
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        #expect(core.accessibilityReturn?.victim == WindowID(1))
        // The yield: a clickless focus report for the foreign
        // regular app, inside the grace.
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
        // One shot: the debt is spent, so a second foreign
        // report is an ordinary focus and is honored.
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(2)
        )
    }

    @Test("A click is the user choosing; the debt clears")
    func clickCancelsTheDebt() {
        let core = makeCore()
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        core.lastLeftClick = (
            at: Date(), point: .zero, reached: WindowID(2)
        )
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(2)
        )
        #expect(core.accessibilityReturn == nil)
    }

    @Test("A report back on our own pid fulfils the debt")
    func ownFocusFulfilsTheDebt() {
        let core = makeCore()
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.accessibilityReturn == nil)
        // The debt is gone, so a later foreign focus follows
        // normally — VoiceOver navigation is never fought once
        // focus came home.
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(2)
        )
    }

    @Test("An expired debt is honored, not returned")
    func expiredDebtIsHonored() {
        let core = makeCore()
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        core.accessibilityReturn?.at = Date(
            timeIntervalSinceNow:
                -KiwiCore.accessibilityReturnGrace - 1
        )
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(2)
        )
        #expect(core.accessibilityReturn == nil)
    }

    @Test("Only an accessibility system process arms the debt")
    func ordinaryPanelsNeverArm() {
        let core = makeCore()
        // Ghostty's quick terminal takes the ignored-panel
        // flag too; its dismissal must not start returning
        // focus (#21/#244 own that flow).
        core.eventLoop.onIgnoredPanelFocus(
            7,
            "com.mitchellh.ghostty"
        )
        #expect(core.accessibilityReturn == nil)
        core.eventLoop.onIgnoredPanelFocus(7, nil)
        #expect(core.accessibilityReturn == nil)
    }

    @Test("A foreign focused window is not a victim")
    func foreignAnchorNeverArms() {
        // The reactivation stack only skips ACCESSORY apps, so
        // a regular app's focused window comes back on its own
        // — arming there would fight macOS doing the right
        // thing.
        let core = makeCore()
        core.state.workspaces.focus(WindowID(2), in: SpaceID(1))
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        #expect(core.accessibilityReturn == nil)
    }
}
