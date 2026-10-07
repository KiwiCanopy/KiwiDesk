import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Granting Accessibility is not a request to tile (#2050): the
/// stored press, the grant page, and the quick menu and mark
/// while KiwiDesk waits for it.
///
/// `.serialized` because titles are matched in English through
/// the process-wide `LocalizationManager`.
@Suite("Start Tiling gate (#2050)", .serialized)
@MainActor
struct StartTilingGateTests {
    /// A distinct suite name per test, removed after it, so no
    /// run reads or leaves the real domain.
    private func scratch(
        _ name: String
    ) -> (defaults: UserDefaults, cleanup: () -> Void) {
        let suite = "org.kiwidesk.tilingconsent.tests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (
            defaults,
            { defaults.removePersistentDomain(forName: suite) }
        )
    }

    // MARK: - The stored press

    /// The #2050 report one launch later: granted, closed the
    /// tour, relaunched — a two-state flag reads that as an old
    /// install and tiles without asking.
    @Test("a first run that granted and relaunched stays idle")
    func firstRunStaysIdleAcrossLaunches() {
        let (defaults, cleanup) = scratch("firstrun")
        defer { cleanup() }

        TilingConsent.seedAtLaunch(isTrusted: false, defaults)
        // Granted later, then relaunched already trusted.
        TilingConsent.seedAtLaunch(isTrusted: true, defaults)

        #expect(!TilingConsent.hasStarted(isTrusted: true, defaults))
    }

    @Test("an install from before the gate counts as started")
    func preGateInstallIsStarted() {
        let (defaults, cleanup) = scratch("pregate")
        defer { cleanup() }

        #expect(TilingConsent.hasStarted(isTrusted: true, defaults))
        TilingConsent.seedAtLaunch(isTrusted: true, defaults)
        #expect(TilingConsent.hasStarted(isTrusted: true, defaults))
    }

    /// A pre-gate user whose grant is missing at upgrade: the
    /// finished tour is the evidence they tiled before.
    @Test("a finished tour marks a pre-gate install")
    func finishedTourIsStarted() {
        let (defaults, cleanup) = scratch("tour")
        defer { cleanup() }

        OnboardingDiscovery.markShown(defaults)
        TilingConsent.seedAtLaunch(isTrusted: false, defaults)

        #expect(TilingConsent.hasStarted(isTrusted: true, defaults))
    }

    @Test("the hold reads the permission before the press")
    func holdRanksThePermission() {
        #expect(
            CoreHold.of(isTrusted: false, hasStarted: true)
                == .permissionMissing
        )
        // A first run: the grant is owed before any press.
        #expect(
            CoreHold.of(isTrusted: false, hasStarted: false)
                == .permissionMissing
        )
        #expect(
            CoreHold.of(isTrusted: true, hasStarted: false)
                == .notStarted
        )
        #expect(
            CoreHold.of(isTrusted: true, hasStarted: true) == .running
        )
    }

    @Test("the press is kept across a revoke")
    func pressSurvivesRevoke() {
        let (defaults, cleanup) = scratch("press")
        defer { cleanup() }

        TilingConsent.seedAtLaunch(isTrusted: false, defaults)
        TilingConsent.markStarted(defaults)

        #expect(TilingConsent.hasStarted(isTrusted: false, defaults))
        #expect(TilingConsent.hasStarted(isTrusted: true, defaults))
    }

    // MARK: - The grant page

    private func grant(
        trusted: Bool,
        started: Bool,
        phase: BootPhase = .ready
    ) -> (OnboardingModel, OnboardingView) {
        LocalizationManager.shared.select("en")
        let model = OnboardingModel()
        model.isTrusted = trusted
        model.hasStartedTiling = started
        model.bootPhase = phase
        return (model, OnboardingView(model: model))
    }

    @Test("a granted page waits for Start Tiling")
    func grantedPageWaits() {
        let (_, view) = grant(trusted: true, started: false)

        #expect(view.grantTitle == "KiwiDesk is ready")
        // The label is interpolated, so the sentence names the
        // button the page actually draws.
        #expect(view.grantBody.hasPrefix("Start Tiling arranges"))
        #expect(view.grantBody.contains("Nothing moves"))
        // No claim about an arrangement nobody asked for.
        #expect(!view.grantBody.contains("have been arranged"))
        #expect(
            view.grantHintForPhase?.contains("menu bar") == true
        )
    }

    /// A phase the page did not start — an earlier session's, a
    /// seeded `.scanning` — must not narrate a scan behind a page
    /// that says nothing moves.
    @Test("a waiting page narrates no scan")
    func waitingPageIgnoresThePhase() {
        let (_, view) = grant(
            trusted: true,
            started: false,
            phase: .scanning(scanned: 3, total: 9)
        )

        #expect(view.grantTitle == "KiwiDesk is ready")
        #expect(!view.isArranging)
        #expect(view.grantHintForPhase?.contains("3 of 9") != true)
    }

    @Test("the press starts tiling only once granted")
    func pressNeedsTheGrant() {
        var presses = 0
        let (model, _) = grant(trusted: false, started: false)
        model.onStartTiling = { presses += 1 }

        model.startTiling()
        #expect(presses == 0)

        model.isTrusted = true
        model.startTiling()
        #expect(presses == 1)

        // Pressed already: the page shows Continue, and a stray
        // call starts nothing twice.
        model.hasStartedTiling = true
        model.startTiling()
        #expect(presses == 1)
    }

    // MARK: - The quick menu and the mark

    private func controller(
        idle: Bool,
        warning: Bool = false
    ) -> StatusItemController {
        LocalizationManager.shared.select("en")
        let controller = StatusItemController(item: FakeStatusItem())
        controller.profilesProvider = {
            (active: "Work", all: ["Work", "Play"], broken: [])
        }
        controller.setWarning(warning)
        controller.setTilingIdle(idle)
        return controller
    }

    private func menu(_ controller: StatusItemController) -> NSMenu {
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        return menu
    }

    @Test("an idle menu leads with Start Tiling")
    func idleMenuLeadsWithStart() {
        var presses = 0
        let controller = controller(idle: true)
        controller.onStartTiling = { presses += 1 }
        let items = menu(controller).items

        let start = items.first
        #expect(start?.title == "Start Tiling")
        #expect(start?.isEnabled == true)
        if let start, let action = start.action {
            _ = (start.target as? NSObject)?.perform(action, with: start)
        }
        #expect(presses == 1)
        // Grey, don't hide (#171): these work once tiling runs.
        let layout = items.first { $0.title == "Layout" }
        let switcher = items.first { $0.title == "Switch Profile" }
        #expect(layout?.isEnabled == false)
        #expect(switcher?.isEnabled == false)
    }

    @Test("a running menu offers no start")
    func runningMenuHasNoStart() {
        let items = menu(controller(idle: false)).items
        #expect(!items.contains { $0.title == "Start Tiling" })
        #expect(items.first { $0.title == "Layout" }?.isEnabled == true)
    }

    /// Without the permission a press could start nothing; the
    /// paused row is the one door then.
    @Test("a missing permission hides the start")
    func permissionOutranksStart() {
        let items = menu(controller(idle: true, warning: true)).items
        #expect(!items.contains { $0.title == "Start Tiling" })
        #expect(
            items.first?.title.hasPrefix("Window Management Paused")
                == true
        )
    }

    @Test("the idle mark dims and says so, without a warning")
    func idleMarkDims() {
        let controller = controller(idle: true)
        let button = controller.anchorButton

        #expect(button?.appearsDisabled == true)
        #expect(button?.accessibilityLabel() == "KiwiDesk (not tiling)")

        controller.setTilingIdle(false)
        #expect(button?.appearsDisabled == false)
        #expect(button?.accessibilityLabel() == "KiwiDesk")
    }

    /// Idle can last indefinitely, so an update offer still
    /// reaches the icon (owner ruling, #2050).
    @Test("an update mark rides the dimmed idle icon")
    func updateMarkRidesIdle() {
        let controller = controller(idle: true)
        let updater = FakeUpdater()
        controller.updater = updater
        updater.updatePending = true
        let button = controller.anchorButton

        #expect(button?.appearsDisabled == true)
        #expect(
            button?.accessibilityLabel()
                == "KiwiDesk (update available)"
        )
    }

    @Test("the permission warning outranks the idle mark")
    func warningOutranksIdleMark() {
        let button = controller(idle: true, warning: true).anchorButton
        #expect(
            button?.accessibilityLabel()
                == "KiwiDesk (permission required)"
        )
    }
}

/// A real button, so the mark is observable; never through
/// `NSStatusBar.system` (`StatusItemSeamGuardTests`).
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = NSStatusBarButton()
    var menu: NSMenu?
}

@MainActor
private final class FakeUpdater: AppUpdating {
    let autoInstall = AutoInstallSetting.inert()
    var whatsNew: WhatsNewCoordinator? { nil }
    let updates = UpdateStateStore()
    var canCheckForUpdates = true
    var updatePending = false { didSet { onUpdatePendingChanged() } }
    var onUpdatePendingChanged: () -> Void = {}
    var onWillRelaunch: () -> Void = {}
    func checkForUpdates() {}
}
