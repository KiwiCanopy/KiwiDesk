import AppKit
import KiwiDeskCore

/// The Settings window's title (#2059 ruling): the area shown —
/// its destination label — or "Settings" on Home, never the app
/// name. The title bar hides it; the Window menu, Mission
/// Control, VoiceOver and the App Bar read it.
@MainActor
enum SettingsWindowTitle {
    /// The title for `destination`, nil being Home. Computed per
    /// read, so it follows the language (localization.md).
    static func of(_ destination: SettingsDestination?) -> String {
        destination?.title ?? L("home.title", "Settings")
    }

    /// Keeps `window.title` on the model's area: written now and
    /// on every write of `destination` or the language, through
    /// `SettingsModel.onWindowTitle`. A search or a detail-panel
    /// selection moves no destination, so it keeps the title.
    static func follow(_ model: SettingsModel, in window: NSWindow) {
        model.onWindowTitle = { [weak window] title in
            window?.title = title
        }
    }
}
