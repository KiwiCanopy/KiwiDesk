import AppKit

/// The app's `NSApplication`: every `terminate(_:)` — Quit, a
/// SIGTERM, an update's relaunch — first clears the confirmation
/// sheets that would abort it (#2049, `QuitSheets`). A logout's
/// quit event never reaches this method, so the power-off
/// notification clears them as well (`AppDelegate+Quit`).
final class KiwiApplication: NSApplication {
    override func terminate(_ sender: Any?) {
        guard
            QuitSheets.clear(
                windows,
                keeper: delegate as? QuitSheetKeeper
            )
        else { return }
        super.terminate(sender)
    }
}
