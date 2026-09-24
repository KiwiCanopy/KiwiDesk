import AppKit
import Sparkle

/// Sparkle UI delegate customizations for an accessory app with no
/// Dock tile (#1011). Held for the process lifetime by
/// `SparkleUpdater`: the standard driver references its delegate
/// WEAKLY, so a policy nobody retains is a policy Sparkle stops
/// asking.
@MainActor
final class UpdatePromptPolicy: NSObject,
    @MainActor SPUStandardUserDriverDelegate
{
    /// A SCHEDULED update waiting behind the gentle reminder
    /// (#1013): set when Sparkle leaves the showing to KiwiDesk,
    /// cleared once the update got attention or the session ended.
    /// The one home of the fact; `onUpdatePendingChanged` nudges
    /// the consumer, which reads it back.
    var updatePending = false {
        didSet { onUpdatePendingChanged() }
    }
    var onUpdatePendingChanged: () -> Void = {}

    /// Gentle reminders (#1013): a background app's scheduled
    /// alert is drawn BEHIND every window, which for a menu-bar
    /// app is drawn nowhere. Sparkle's own warning names this.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// A scheduled update is KiwiDesk's to show whatever focus
    /// Sparkle proposes: an unsolicited offer never takes the
    /// screen (#1013; #1011 is the opposite rule). User-initiated
    /// checks never reach this answer.
    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        updatePending = !handleShowingUpdate
    }

    func standardUserDriverDidReceiveUserAttention(
        forUpdate update: SUAppcastItem
    ) {
        updatePending = false
    }

    func standardUserDriverWillFinishUpdateSession() {
        updatePending = false
    }

    /// KiwiDesk's own window got an offer (#1542): the same answer
    /// as above — a scheduled one waits behind the mark, a user's
    /// own check shows now. True when it shows.
    func offerArrived(userInitiated: Bool) -> Bool {
        updatePending = !userInitiated
        return userInitiated
    }

    /// The own window's offer is on screen.
    func offerGotAttention() {
        updatePending = false
    }

    /// Disallows minimizing the status window (#1011): activating
    /// a process deminiaturizes nothing, so a parked prompt would
    /// sit in a Dock KiwiDesk has no icon in — refusing the
    /// affordance is what closes the parking route, and only that.
    func standardUserDriverAllowsMinimizableStatusWindow() -> Bool {
        false
    }

    /// Activates app for modal alerts — unconditional only because
    /// Sparkle gates them on user engagement
    /// (`SPUScheduledUpdateDriver.m`, Sparkle 2.9.6); check that
    /// gate when the version moves.
    func standardUserDriverWillShowModalAlert() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Custom Sparkle user driver ensuring prompts come to front without Dock
/// bouncing (#1011), and handing a found update to KiwiDesk's own
/// window (#1542): each override below routes a phase to that
/// window while one is open and defers to Sparkle otherwise.
/// Checking, "up to date" and the download and install stay
/// Sparkle's.
@MainActor
final class UpdatePromptDriver: SPUStandardUserDriver {
    /// The policy the driver answers from, typed — Sparkle holds
    /// its delegate weakly and untyped.
    let prompts: UpdatePromptPolicy
    /// Every item of the appcast Sparkle last loaded: the source
    /// of "everything since your version".
    var loadedItems: [SUAppcastItem] = []
    /// Starts a user-initiated check; Try Again's door.
    var startCheck: () -> Void = {}
    var window: UpdateWindowController?
    /// Puts the window on screen; a test records it instead.
    var presents: (UpdateWindowController) -> Void = { $0.present() }
    /// Replaces Sparkle's modal error alert in a test, which would
    /// otherwise block the run; nil is Sparkle's own.
    var sparkleError: ((any Error, @escaping () -> Void) -> Void)?
    /// Replaces Sparkle's own ready-to-install prompt in a test,
    /// for the same reason; nil is Sparkle's own.
    var sparkleReadyToInstall: (() -> SPUUserUpdateChoice)?

    init(hostBundle: Bundle, delegate: UpdatePromptPolicy) {
        prompts = delegate
        super.init(hostBundle: hostBundle, delegate: delegate)
    }

    override func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        guard !appcastItem.isInformationOnlyUpdate else {
            closeWindow()
            return super.showUpdateFound(
                with: appcastItem,
                state: state,
                reply: reply
            )
        }
        showUpdateFound(
            appcastItem,
            userInitiated: state.userInitiated,
            stage: state.stage,
            reply: reply
        )
    }

    override func showUpdateInFocus() {
        guard window != nil else { return super.showUpdateInFocus() }
        presentWindow()
    }

    override func showUserInitiatedUpdateCheck(
        cancellation: @escaping () -> Void
    ) {
        guard let window, window.session.retry == .checking else {
            return super.showUserInitiatedUpdateCheck(
                cancellation: cancellation
            )
        }
        window.session.checkStarted(cancellation: cancellation)
    }

    /// Restores app activation when the download starts (#1011):
    /// the Install click closes Sparkle's alert BEFORE the
    /// completion block runs, deactivating a now window-less
    /// accessory app. After `super`, so the status window exists
    /// when the app is raised. Our own window stays open through
    /// the click, so it needs neither.
    override func showDownloadInitiated(
        cancellation: @escaping () -> Void
    ) {
        if let window {
            return window.session.downloadStarted(
                cancellation: cancellation
            )
        }
        super.showDownloadInitiated(cancellation: cancellation)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func showDownloadDidReceiveExpectedContentLength(
        _ expectedContentLength: UInt64
    ) {
        guard let window else {
            return super.showDownloadDidReceiveExpectedContentLength(
                expectedContentLength
            )
        }
        window.session.downloadExpects(expectedContentLength)
    }

    override func showDownloadDidReceiveData(ofLength length: UInt64) {
        guard let window else {
            return super.showDownloadDidReceiveData(ofLength: length)
        }
        window.session.downloadReceived(length)
    }

    override func showDownloadDidStartExtractingUpdate() {
        guard let window else {
            return super.showDownloadDidStartExtractingUpdate()
        }
        window.session.preparing()
    }

    /// Sparkle's cycle ended — the one moment Try Again's check
    /// can start (`SPUUpdater` allows a new session from here).
    func updateCycleFinished() {
        window?.session.cycleEnded()
    }

    /// Preparing draws an indeterminate bar, so the window reads
    /// nothing from the extraction's progress.
    override func showExtractionReceivedProgress(_ progress: Double) {
        guard window == nil else { return }
        super.showExtractionReceivedProgress(progress)
    }

    /// Brings app to front before the install-and-restart prompt
    /// (#1011). Depends on `UpdatePromptPolicy` refusing the
    /// minimize button — a parked window is the one state
    /// activation cannot recover. Our own window already had its
    /// Install, so it answers without asking twice.
    override func showReadyToInstallAndRelaunch() async
        -> SPUUserUpdateChoice
    {
        if let window {
            window.session.installing(retryTermination: nil)
            return .install
        }
        if let sparkleReadyToInstall { return sparkleReadyToInstall() }
        NSApp.activate(ignoringOtherApps: true)
        return await super.showReadyToInstallAndRelaunch()
    }

    override func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        guard let window else {
            return super.showInstallingUpdate(
                withApplicationTerminated: applicationTerminated,
                retryTerminatingApplication: retryTerminatingApplication
            )
        }
        window.session.installing(
            retryTermination: applicationTerminated
                ? nil : retryTerminatingApplication
        )
    }

    /// A failure after the offer holds Sparkle's acknowledgement
    /// until the window's Later or Try Again answers it.
    override func showUpdaterError(
        _ error: any Error,
        acknowledgement: @escaping () -> Void
    ) {
        guard let window, window.session.phase != .found else {
            if let sparkleError {
                return sparkleError(error, acknowledgement)
            }
            return super.showUpdaterError(
                error,
                acknowledgement: acknowledgement
            )
        }
        window.session.failed(acknowledgement: acknowledgement)
        presentWindow()
    }

    override func dismissUpdateInstallation() {
        if let window, !window.session.dismissed() {
            closeWindow()
        }
        super.dismissUpdateInstallation()
    }
}
