import AppKit

/// The app's `NSApplication`: every `terminate(_:)` — Quit, a
/// SIGTERM, an update's relaunch — first closes the sheets that
/// would abort it (#2049, `QuitSheets`). A logout's quit event
/// never reaches this method, so the power-off notification
/// closes them as well (`AppDelegate+Quit`).
final class KiwiApplication: NSApplication {
    /// Set by a quit that cannot wait for an answer (SIGTERM): the
    /// Settings draft is discarded rather than asked about.
    private(set) var quitDiscardsDraft = false

    override func terminate(_ sender: Any?) {
        QuitSheets.clearOwnWindows()
        super.terminate(sender)
    }

    /// The SIGTERM quit: nothing may ask (#2049 ruling).
    func terminateDiscardingDraft() {
        quitDiscardsDraft = true
        terminate(nil)
        quitDiscardsDraft = false
    }
}
