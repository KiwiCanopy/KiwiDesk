import AppKit
import Foundation

/// Reads the macOS "Displays have separate Spaces" preference.
///
/// Stored as `spans-displays` in the `com.apple.spaces` domain:
/// `1` (true) means every display shares one Space — the setting
/// is OFF; absent or `0` means each display has its own Spaces
/// (the default).
///
/// The value can't be changed programmatically and only takes
/// effect after a logout, so this is read-only detection that
/// lets onboarding recommend the shared model when needed (#8).
public enum DisplaySpacesSetting {
    /// True when displays have separate Spaces (or the default is
    /// in effect). False only when the user explicitly turned the
    /// setting off (`spans-displays = 1`).
    public static func hasSeparateSpaces() -> Bool {
        let value = CFPreferencesCopyAppValue(
            "spans-displays" as CFString,
            "com.apple.spaces" as CFString
        )
        // Absent/unreadable (nil, or stored under a host this API
        // doesn't resolve): assume the default, separate Spaces.
        // The only consequence is showing a recommendation and
        // warning, so the conservative default is benign.
        guard let number = value as? NSNumber else { return true }
        return number.intValue != 1
    }

    /// True when the display setup makes shared Spaces worth
    /// recommending: separate Spaces are on *and* more than one
    /// display is present. A single display has no Desktop→profile
    /// binding ambiguity, so the recommendation must not fire for
    /// it. The one predicate both onboarding and the Canvas
    /// section share, so the two surfaces can't drift (#8).
    public static func recommendsSharedSpaces(
        displayCount: Int
    ) -> Bool {
        displayCount > 1 && hasSeparateSpaces()
    }

    /// Opens System Settings › Desktop & Dock, where the option
    /// lives. Falls back to the Settings root if Apple renames
    /// the pane identifier.
    @MainActor
    public static func openSystemSettings() {
        let pane =
            "x-apple.systempreferences:"
            + "com.apple.Desktop-Settings.extension"
        let target =
            URL(string: pane)
            ?? URL(string: "x-apple.systempreferences:")
        guard let target else { return }
        NSWorkspace.shared.open(target)
    }
}
