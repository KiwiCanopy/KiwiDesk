import AppKit

/// The app's `NSApplication`: every `terminate(_:)` — Quit, a
/// SIGTERM, an update's relaunch — first closes the sheets that
/// would abort it (#2049, `QuitSheets`), or brings forward the
/// unsaved-edits question a quit is already waiting on. A logout's
/// quit event never reaches this method, so the power-off
/// notification takes the same door (`AppDelegate+Quit`).
final class KiwiApplication: NSApplication {
    override func terminate(_ sender: Any?) {
        guard QuitSheets.clearOwnWindows() else { return }
        super.terminate(sender)
    }
}
