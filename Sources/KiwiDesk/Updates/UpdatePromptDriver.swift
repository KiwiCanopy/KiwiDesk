import AppKit
import Sparkle

/// Custom Sparkle user driver ensuring prompts come to front without Dock
/// bouncing (#1011), and handing a found update to KiwiDesk's own
/// window (#1542): each override below routes a phase to that
/// window while one is open and defers to Sparkle otherwise.
/// A user's check and "up to date" are the window's too (#1849);
/// any other no-update reason keeps Sparkle's own wording.
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
    /// The one update window on screen (#1849), replaced only
    /// through `replace(with:presenting:)`.
    var current: UpdateWindowSlot? {
        didSet {
            let was = oldValue?.isAnswer ?? false
            let isAnswer = current?.isAnswer ?? false
            if was != isAnswer { onAnswerOpen(isAnswer) }
        }
    }
    /// A not-found answer waiting on its list.
    var pendingUpToDate: PendingUpToDate?
    /// Where the window's own Install records its notes as read;
    /// nil keeps a test's driver off the real defaults.
    var seenRecord: WhatsNewRecord?
    /// Fetches "Next on my list" while an offer is open, so the
    /// relaunch carries it (#1813). `SparkleUpdater` wires it; nil
    /// keeps a test's driver offline.
    var fetchNext: (() async -> NextOnMyList?)?
    /// The open offer's fetch, cancelled with its window; a test
    /// awaits it.
    var nextFetch: Task<Void, Never>?
    /// What that fetch returned.
    var offeredNext: NextOnMyList?
    /// Puts an update window on screen; a test records it instead.
    var presents: (UpdateWindowSlot) -> Void = { $0.present() }
    /// Told as the answer opens and closes, so Home narrates it
    /// while Sparkle's session waits on the window's Done.
    var onAnswerOpen: (Bool) -> Void = { _ in }
    /// Replaces Sparkle's modal error alert in a test, which would
    /// otherwise block the run; nil is Sparkle's own.
    var sparkleError: ((any Error, @escaping () -> Void) -> Void)?
    /// Replaces Sparkle's modal no-update alert in a test; nil is
    /// Sparkle's own.
    var sparkleNotFound: ((any Error, @escaping () -> Void) -> Void)?
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
            // Sparkle's own alert answers; it is modal, so nothing
            // under it can take the focus back.
            replace(with: nil)
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

    /// "You're up to date" in the window (#1849), the list fetched
    /// first while Sparkle's Checking window stays up. Every other
    /// no-update reason — a system too old, say — keeps Sparkle's
    /// explanation.
    override func showUpdateNotFoundWithError(
        _ error: any Error,
        acknowledgement: @escaping () -> Void
    ) {
        guard Self.isUpToDate(error) else {
            replace(with: nil)
            if let sparkleNotFound {
                return sparkleNotFound(error, acknowledgement)
            }
            return super.showUpdateNotFoundWithError(
                error,
                acknowledgement: acknowledgement
            )
        }
        awaitUpToDate(acknowledgement: acknowledgement)
    }

    override func showUpdateInFocus() {
        if !focusOpenWindow() { super.showUpdateInFocus() }
    }

    override func showUserInitiatedUpdateCheck(
        cancellation: @escaping () -> Void
    ) {
        guard let window, window.session.retry == .checking else {
            return showChecking(cancellation: cancellation)
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
        if checking != nil { replace(with: nil) }
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

    /// Sparkle's session ended: whatever it held ends with it — a
    /// pending answer unacknowledged, since its session is gone —
    /// save an offer kept for Try Again.
    override func dismissUpdateInstallation() {
        pendingUpToDate?.fetch.cancel()
        pendingUpToDate = nil
        if let window {
            if !window.session.dismissed() { replace(with: nil) }
        } else {
            replace(with: nil)
        }
        super.dismissUpdateInstallation()
    }
}
