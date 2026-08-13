import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The second, unchunked `reconcileAll` boot used to run (#836).
///
/// The chunked scan's epilogue publishes displays from inside
/// `scanChunk`; the monitor-change handler loads the matching
/// profile; that profile's window rules reach
/// `setResolvedWindowRules`, which reconciled every app again —
/// unchunked, unbudgeted, still inside the boot phase, and billed
/// to the boot summary's own `scan` figure. The measured cost was
/// one AX-unresponsive helper paid for twice.
///
/// Both arms are here on purpose. A suppression test alone passes
/// just as well when the reconcile is deleted outright, and
/// deleting it is the one change that would silently drop the
/// rule re-check for every steady-state profile switch.
///
/// The skip's safety rests on the startup sweep running the same
/// two loops chunked a second later. That dependency is pinned
/// where it lives, not asserted here: `StartupSweepTests` for the
/// sweep doing the work, `StartupSweepWiringTests` for the boot
/// tail still scheduling it.
@MainActor
@Suite("Boot window-rule reconcile (#836)")
struct BootWindowRuleReconcileTests {
    @MainActor
    private final class CountBox {
        var windowQueries = 0
    }

    /// Inert healthy observer: attach installs it, nothing fires,
    /// registration never needs repair (#675).
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        let needsRegistrationRepair = false
        func observe(window: AXUIElement) {}
        func repairRegistration() {}
        func invalidate() {}
    }

    /// A core with one attached app, scanned whole (a suite has
    /// no run loop to yield to, so it drains with no budget), and
    /// a counter on the reconcile's own AX call.
    private func makeScannedCore() -> (KiwiCore, CountBox) {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-836-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 900)
        }
        core.onLog = { _ in }
        let loop = core.eventLoop
        let box = CountBox()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.activationPolicy = { _ in .regular }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { _ in
            box.windowQueries += 1
            return []
        }
        loop.runningApplications = {
            [
                RunningApp(
                    pid: 836_001,
                    activationPolicy: .regular,
                    ref: AppRef(
                        bundleID: "test.kiwi.boot836",
                        name: "Boot836"
                    )
                )
            ]
        }
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        return (core, box)
    }

    /// The profile-reload path, entered exactly as
    /// `apply(profile:)` and `apply(composed:)` enter it. Not
    /// GUI-managed here (the scratch directory holds no
    /// `gui.json`), so it goes straight to the window-rule write
    /// under test rather than returning early on the sidecar.
    ///
    /// `float` names a float rule the profile adds, and every
    /// caller that wants the reconcile passes a DIFFERENT one:
    /// the write returns before the gate when the rules resolve
    /// to what is already installed, so a fixture re-applying the
    /// same rules exercises the equality skip and never reaches
    /// the deferral it meant to test.
    private func reapplyRules(
        _ core: KiwiCore,
        float: String? = nil
    ) {
        #expect(!core.isGuiManaged)
        core.reapplyStructuredOverrides(
            profileModes: nil,
            profileAppRules: nil,
            profileFloatRules: float.map {
                RuleListOverride(rules: [$0: true])
            },
            profileIgnoreRules: nil
        )
    }

    @Test("a profile's rules re-check every app once boot is done")
    func rulesReconcileWhenBootHasFinished() {
        let (core, box) = makeScannedCore()
        defer { core.eventLoop.stop() }
        let before = box.windowQueries
        reapplyRules(core, float: "com.test.floater")
        // The window snapshot is the reconcile's own AX call, and
        // nothing else on this path takes one.
        #expect(box.windowQueries > before)
    }

    @Test("and stand down while the boot scan is still open")
    func rulesDoNotReconcileDuringTheBootScan() {
        let (core, box) = makeScannedCore()
        defer { core.eventLoop.stop() }
        core.defersWindowRuleReconcileToSweep = true
        let before = box.windowQueries
        reapplyRules(core, float: "com.test.floater")
        #expect(box.windowQueries == before)
    }

    /// The PRIMARY mechanism, and the reason the deferral above
    /// is rarely reached: `reconcileAll` here exists to
    /// re-classify windows against rules that CHANGED, so an
    /// apply resolving to the rules already installed has nothing
    /// to do. The boot case #836 measured is mostly this one — a
    /// profile re-applied over the families `loadConfig` just
    /// installed — and it now costs nothing rather than being
    /// postponed, which is what keeps the deferral's re-
    /// classification residue off the ordinary boot.
    ///
    /// Asserted with boot FINISHED, so a green cannot be bought
    /// by the deferral: the only thing standing between this
    /// fixture and a reconcile is the equality check.
    @Test("re-applying the same rules reconciles nothing")
    func unchangedRulesReconcileNothing() {
        let (core, box) = makeScannedCore()
        defer { core.eventLoop.stop() }
        // Install the rule once, so the second apply is the
        // no-change case rather than the first-write case.
        reapplyRules(core, float: "com.test.floater")
        let before = box.windowQueries
        #expect(before > 0)
        reapplyRules(core, float: "com.test.floater")
        #expect(box.windowQueries == before)
    }

    /// The other skip, unchanged by #836 and asserted so the new
    /// clause cannot be written in a way that swallows it: while
    /// `loadConfig` is writing the rule families it runs one pass
    /// itself afterwards, so no call site here may run its own.
    @Test("the config load's own deferral still suppresses it")
    func configDeferralStillSuppresses() {
        let (core, box) = makeScannedCore()
        defer { core.eventLoop.stop() }
        core.defersWindowRuleReconcile = true
        let before = box.windowQueries
        reapplyRules(core, float: "com.test.floater")
        #expect(box.windowQueries == before)
    }
}
