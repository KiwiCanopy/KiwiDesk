import Foundation

/// Reads the macOS "Displays have separate Spaces" preference.
///
/// Stored as `spans-displays` in the `com.apple.spaces` domain:
/// `1` (true) means every display shares one Space — the setting
/// is OFF; absent or `0` means each display has its own Spaces
/// (the default, and what per-monitor space mapping needs, #6).
///
/// The value can't be changed programmatically and only takes
/// effect after a logout, so this is read-only detection that
/// lets the onboarding step (#8) skip itself when already on.
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
        // The only consequence is the onboarding step not
        // self-skipping, so the conservative default is benign.
        guard let number = value as? NSNumber else { return true }
        return number.intValue != 1
    }
}
