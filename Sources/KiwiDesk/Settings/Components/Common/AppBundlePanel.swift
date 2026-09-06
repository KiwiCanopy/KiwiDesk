import AppKit
import KiwiDeskCore

/// The "Other…" escape both app pickers share (#1279).
///
/// The picker's list is built from a disk scan, and a scan can
/// always be one folder shy of where someone keeps an app — a
/// dev build, another volume. Browsing is the escape for that,
/// and it is the ONLY escape either surface offers: typing a
/// bundle identifier by hand was the App Rules row's own answer
/// and is retired, because a user who genuinely needs to name an
/// app that is not installed writes Lua.
enum AppBundlePanel {
    /// Asks for an app on disk, or nil.
    ///
    /// Two nils, one narrated: a cancelled panel is the user
    /// saying no, but a bundle with no identifier is a pick that
    /// silently does nothing — a residue no caller covers.
    @MainActor static func pick()
        -> KeybindingCatalog.InstalledApp?
    {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.directoryURL = URL(
            fileURLWithPath: "/Applications"
        )
        guard panel.runModal() == .OK, let url = panel.url,
            let bundleID = Bundle(url: url)?
                .bundleIdentifier?.lowercased()
        else { return nil }
        return .init(
            bundleID: bundleID,
            name: KeybindingCatalog.displayName(
                forBundleID: bundleID
            )
        )
    }
}
