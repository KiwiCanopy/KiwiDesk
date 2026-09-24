import Foundation
import Sparkle

/// Where the update window stands (#1542 ruling ▸ States). Checking
/// and "up to date" stay Sparkle's and never reach it.
enum UpdateWindowPhase: Equatable {
    case found
    /// `expected` is nil until Sparkle learns the length, or when
    /// the server does not send one.
    case downloading(received: UInt64, expected: UInt64?)
    case preparing
    /// Only until KiwiDesk quits, or while a password prompt is open.
    case installing
    case failed(UpdateFailure)

    /// Whether the window's close (Escape, ⌘W, the button) is
    /// honoured: Later where the footer offers it, Cancel while
    /// the download can still stop.
    var closes: Bool {
        switch self {
        case .found, .failed, .downloading: return true
        case .preparing, .installing: return false
        }
    }
}

enum UpdateFailure: Equatable {
    /// The download or its extraction failed, or the retried
    /// check did.
    case download
    /// KiwiDesk did not quit when the installer asked it to.
    case quit
}

/// One update offer's lifetime in the window: the phase it draws
/// and the Sparkle handles its buttons answer. The driver feeds
/// Sparkle's callbacks in; the view calls the actions.
@MainActor
final class UpdateSession: ObservableObject {
    @Published private(set) var phase: UpdateWindowPhase = .found

    /// A Try Again after a failed download: Sparkle ends the
    /// failed session and a fresh check re-finds the update,
    /// which the window then installs without asking again.
    enum Retry: Equatable {
        case none
        /// The failure was acknowledged; Sparkle's dismiss follows.
        case acknowledging
        /// Dismissed; the check waits for Sparkle's cycle to end,
        /// since a check started inside it only re-shows the offer.
        case waiting
        /// The fresh check is running.
        case checking
    }
    private(set) var retry: Retry = .none

    private var reply: ((SPUUserUpdateChoice) -> Void)?
    private var cancellation: (() -> Void)? {
        didSet { canCancel = cancellation != nil }
    }
    /// Whether Cancel can still stop something: a download, or
    /// Try Again's check.
    @Published private(set) var canCancel = false
    /// Where Install lands: a download already fetched in the
    /// background goes straight to Preparing.
    private let installsFrom: UpdateWindowPhase
    private var acknowledgement: (() -> Void)?
    private var retryTermination: (() -> Void)?

    /// Starts the check a Try Again needs; set by the driver.
    var startCheck: () -> Void = {}
    /// Hides the window without ending the session.
    var hide: () -> Void = {}
    /// Closes the window: Later answered the offer.
    var end: () -> Void = {}
    /// Arms the check that KiwiDesk quit after the installer
    /// asked it to: ten seconds, or by hand in a test.
    var armQuitWatch: (@escaping @MainActor () -> Void) -> Void = {
        fire in
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            MainActor.assumeIsolated(fire)
        }
    }
    /// Only the latest armed watch may fail the install.
    private var quitWatch = 0

    init(
        reply: @escaping (SPUUserUpdateChoice) -> Void,
        installsFrom: UpdateWindowPhase = .downloading(
            received: 0,
            expected: nil
        )
    ) {
        self.reply = reply
        self.installsFrom = installsFrom
    }

    // MARK: - Sparkle → session

    /// The fresh check found the update again: install it.
    func refound(reply: @escaping (SPUUserUpdateChoice) -> Void) {
        retry = .none
        phase = .downloading(received: 0, expected: nil)
        reply(.install)
    }

    /// Try Again's fresh check started; Cancel stops it.
    func checkStarted(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func downloadStarted(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
        phase = .downloading(received: 0, expected: nil)
    }

    func downloadExpects(_ length: UInt64) {
        guard case .downloading(let received, _) = phase else { return }
        phase = .downloading(
            received: received,
            expected: length > 0 ? length : nil
        )
    }

    func downloadReceived(_ length: UInt64) {
        guard case .downloading(let received, let expected) = phase
        else { return }
        phase = .downloading(
            received: received + length,
            expected: expected
        )
    }

    func preparing() {
        cancellation = nil
        phase = .preparing
    }

    /// The installer sent its quit, or the relaunch is under way.
    func installing(retryTermination: (() -> Void)?) {
        self.retryTermination = retryTermination
        phase = .installing
        if retryTermination != nil { watchQuit() }
    }

    private func watchQuit() {
        quitWatch += 1
        let armed = quitWatch
        armQuitWatch { [weak self] in
            guard let self, self.quitWatch == armed else { return }
            self.quitStalled()
        }
    }

    /// KiwiDesk is still running well after the installer asked
    /// it to quit.
    func quitStalled() {
        guard phase == .installing, retryTermination != nil
        else { return }
        phase = .failed(.quit)
    }

    func failed(acknowledgement: @escaping () -> Void) {
        self.acknowledgement = acknowledgement
        cancellation = nil
        retry = .none
        phase = .failed(.download)
    }

    /// Sparkle tore the session down. True when the window stays:
    /// only the dismiss a Try Again's acknowledgement causes.
    func dismissed() -> Bool {
        guard retry == .acknowledging else { return false }
        retry = .waiting
        return true
    }

    /// Sparkle's update cycle ended: Try Again's check may start.
    func cycleEnded() {
        guard retry == .waiting else { return }
        retry = .checking
        startCheck()
    }

    // MARK: - Buttons → Sparkle

    func install() {
        guard phase == .found else { return }
        phase = installsFrom
        reply?(.install)
        reply = nil
    }

    /// Later, Escape, ⌘W or the close button.
    func later() {
        switch phase {
        case .found:
            reply?(.dismiss)
            reply = nil
            end()
        case .failed(.download):
            acknowledge()
        case .failed(.quit):
            // Sparkle still installs when KiwiDesk next quits.
            hide()
        case .downloading where canCancel:
            cancel()
        case .downloading:
            // Nothing left to cancel: a stall must still close.
            end()
        case .preparing, .installing:
            break
        }
    }

    func cancel() {
        guard case .downloading = phase else { return }
        cancellation?()
        cancellation = nil
    }

    func tryAgain() {
        switch phase {
        case .failed(.download):
            retry = .acknowledging
            phase = .downloading(received: 0, expected: nil)
            acknowledge()
        case .failed(.quit):
            phase = .installing
            retryTermination?()
            watchQuit()
        default:
            break
        }
    }

    private func acknowledge() {
        let acknowledgement = self.acknowledgement
        self.acknowledgement = nil
        acknowledgement?()
    }
}
