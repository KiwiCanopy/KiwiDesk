import Foundation
import Sparkle
import Testing

@testable import KiwiDesk

/// The update window's phases and the Sparkle handles its buttons
/// answer (#1542 ruling ▸ States), driven without Sparkle.
@MainActor
@Suite("Update window session (#1542)")
struct UpdateSessionTests {
    private final class Log {
        var replies: [SPUUserUpdateChoice] = []
        var cancels = 0
        var acks = 0
        var checks = 0
        var retries = 0
        var hides = 0
        var ends = 0
        var watches: [@MainActor () -> Void] = []
    }

    private func session() -> (UpdateSession, Log) {
        let log = Log()
        let session = UpdateSession { log.replies.append($0) }
        session.startCheck = { log.checks += 1 }
        session.hide = { log.hides += 1 }
        session.end = { log.ends += 1 }
        session.armQuitWatch = { log.watches.append($0) }
        return (session, log)
    }

    @Test("Install answers Sparkle once and starts downloading")
    func installReplies() {
        let (session, log) = session()
        session.install()
        session.install()
        #expect(log.replies == [.install])
        #expect(session.phase == .downloading(received: 0, expected: nil))
    }

    /// Escape, ⌘W and the close button all mean Later, and Later
    /// ends the window without waiting on Sparkle.
    @Test("Later dismisses and ends the window")
    func laterDismisses() {
        let (session, log) = session()
        session.later()
        #expect(log.replies == [.dismiss])
        #expect(log.ends == 1)
    }

    @Test("progress accumulates against the expected length")
    func progressAccumulates() {
        let (session, _) = session()
        session.downloadStarted {}
        session.downloadExpects(100)
        session.downloadReceived(30)
        session.downloadReceived(20)
        #expect(session.phase == .downloading(received: 50, expected: 100))
        #expect(session.canCancel)
        session.preparing()
        #expect(session.phase == .preparing)
        #expect(!session.canCancel)
    }

    /// While downloading the close means Cancel; once preparing
    /// nothing can stop it and the close is refused.
    @Test("the close cancels a download and is refused after")
    func closeFollowsThePhase() {
        let (session, log) = session()
        session.downloadStarted { log.cancels += 1 }
        #expect(session.phase.closes)
        session.later()
        #expect(log.cancels == 1)
        session.preparing()
        #expect(!session.phase.closes)
        session.installing(retryTermination: nil)
        #expect(!session.phase.closes)
    }

    /// A failed download holds Sparkle's acknowledgement until the
    /// user answers; Try Again acknowledges, keeps the window
    /// through the dismiss that follows, checks again, and
    /// installs what the check re-finds without asking.
    @Test("Try Again re-checks and installs without asking")
    func tryAgainAfterDownloadFailure() {
        let (session, log) = session()
        session.install()
        session.failed { log.acks += 1 }
        #expect(session.phase == .failed(.download))
        #expect(log.acks == 0)
        session.tryAgain()
        #expect(log.acks == 1)
        #expect(session.retry == .acknowledging)
        #expect(session.dismissed())
        #expect(log.checks == 1)
        #expect(session.retry == .checking)
        var refound: [SPUUserUpdateChoice] = []
        session.refound { refound.append($0) }
        #expect(refound == [.install])
        #expect(session.retry == .none)
        // Any later dismiss closes the window.
        #expect(!session.dismissed())
    }

    @Test("Later after a failed download acknowledges it")
    func laterAfterFailure() {
        let (session, log) = session()
        session.install()
        session.failed { log.acks += 1 }
        session.later()
        #expect(log.acks == 1)
        #expect(!session.dismissed())
    }

    /// KiwiDesk still running past the grace after the installer's
    /// quit is the quit failure; Try Again re-sends the quit.
    @Test("a stalled quit fails, and Try Again re-sends it")
    func stalledQuit() throws {
        let (session, log) = session()
        session.installing { log.retries += 1 }
        try #require(log.watches.count == 1)
        log.watches[0]()
        #expect(session.phase == .failed(.quit))
        session.tryAgain()
        #expect(log.retries == 1)
        #expect(session.phase == .installing)
        // The first watch is spent; only the re-armed one counts.
        try #require(log.watches.count == 2)
        log.watches[0]()
        #expect(session.phase == .installing)
        session.later()
        #expect(log.hides == 0)
        log.watches[1]()
        #expect(session.phase == .failed(.quit))
    }

    /// Later on a stalled quit hides the window: Sparkle still
    /// installs when KiwiDesk next quits.
    @Test("Later on a stalled quit hides without ending")
    func laterOnStalledQuit() throws {
        let (session, log) = session()
        session.installing {}
        try #require(log.watches.count == 1)
        log.watches[0]()
        session.later()
        #expect(log.hides == 1)
        #expect(log.ends == 0)
    }

    /// An install whose quit already happened has nothing to
    /// retry, so no watch fails it.
    @Test("a terminated install is never failed")
    func terminatedInstallStays() {
        let (session, log) = session()
        session.installing(retryTermination: nil)
        #expect(log.watches.isEmpty)
        session.quitStalled()
        #expect(session.phase == .installing)
    }
}
