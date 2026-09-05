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

    /// The return's log phrase, asserted POSITIVELY on a
    /// genuine return and NEGATIVELY on the silent let-outs —
    /// one constant, so a reword of the production line reds
    /// the positive half instead of leaving the negative one
    /// vacuously green (guard-prover + re-review, 2026-08-27).
    private static let returnLogNeedle =
        "accessibility-steal yield"

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
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
        // The POSITIVE half of the needle pair (see
        // `returnLogNeedle`).
        #expect(
            log.contains { $0.contains(Self.returnLogNeedle) }
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
        // The arm must have fired for the let-out to prove
        // anything — fail-open otherwise (guard-prover).
        #expect(core.accessibilityReturn != nil)
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
        // Fulfilment must be SILENT — cleared without firing
        // the return. The log capture is what pins the
        // `reportedPid != own` clause: without it an own-pid
        // report is "returned" to itself, which no focus
        // assertion can tell apart (guard-prover, 2026-08-27).
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.accessibilityReturn == nil)
        #expect(
            !log.contains { $0.contains(Self.returnLogNeedle) }
        )
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
        // Fail-open guard: the backdate below no-ops on nil,
        // so prove the arm fired first (guard-prover).
        #expect(core.accessibilityReturn != nil)
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

    @Test("Our own raise fallout never spends the debt")
    func raiseFalloutDoesNotSpendTheDebt() {
        // The review-round major (2026-08-27): the yield lands
        // 3-8 s after the steal, and inside that window our
        // own raises emit clickless foreign focus echoes. The
        // return arm runs LAST among the consumes so a report
        // the z-order echo machine claims leaves the one-shot
        // debt for the genuine yield.
        let core = makeCore()
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        core.zOrderRaiseEchoes[WindowID(2)] = Date()
        core.handle(.windowFocused(WindowID(2)))
        // The echo machine reverted the report; the debt
        // survived it.
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
        #expect(core.accessibilityReturn != nil)
        // The genuine yield — unstamped, clickless, foreign —
        // still gets returned.
        core.zOrderRaiseEchoes[WindowID(2)] = nil
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
        #expect(core.accessibilityReturn == nil)
    }

    @Test("A self-raise echo fall-through never spends it")
    func selfEchoFallThroughDoesNotSpendTheDebt() {
        // The re-review major (2026-08-27): a stamped echo of
        // our OWN raise can fall PAST the self-echo drop block
        // (a non-defer layout) while still being our fallout —
        // the `!selfEcho` gate stands the arm down there, so
        // the debt survives for the genuine yield.
        let core = makeCore()
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        core.selfRaiseStamps[WindowID(2)] = Date()
        core.handle(.windowFocused(WindowID(2)))
        // The echo was honored as our own raise's fallout —
        // and the debt is intact.
        #expect(core.accessibilityReturn != nil)
        // The genuine yield — the stamp aged out (an echo never
        // consumes one, #887) — is returned.
        core.selfRaiseStamps[WindowID(2)] = nil
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
        #expect(core.accessibilityReturn == nil)
    }

    @Test("A stale unconsumed debt is replaced, not kept")
    func staleDebtIsReplaced() {
        // The renewal guard refuses only a LIVE debt: one that
        // expired unconsumed (the yield landed on an untracked
        // window) must not block a later VoiceOver start with
        // the same victim (re-review, 2026-08-27).
        let core = makeCore()
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        core.accessibilityReturn?.at = Date(
            timeIntervalSinceNow:
                -KiwiCore.accessibilityReturnGrace - 1
        )
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        let at = core.accessibilityReturn?.at
        #expect(at != nil)
        #expect(
            at.map { Date().timeIntervalSince($0) < 2 } == true
        )
    }

    @Test("A lazy panel re-report never renews the grace")
    func reReportDoesNotRenewTheDebt() {
        // Sliding `at` forward stretches the grace past its
        // bound, and each renewal is another chance to fight a
        // deliberate clickless move — the first steal's clock
        // stands (#689's semantic-re-arm shape).
        let core = makeCore()
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        let aged = Date(timeIntervalSinceNow: -5)
        core.accessibilityReturn?.at = aged
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
        #expect(core.accessibilityReturn?.at == aged)
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
