import Foundation

/// Reads the macOS "Displays have separate Spaces" preference.
///
/// Stored as `spans-displays` in the `com.apple.spaces` domain:
/// `1` (true) means every display shares one Space — the setting
/// is OFF; absent or `0` means each display has its own Spaces
/// (the default).
///
/// The value can't be changed programmatically and only takes
/// effect after a logout, so this is read-only detection. Its one
/// production reader is the native-Space switch handler, which
/// uses it to tell a secondary display's Desktop switch from a
/// repeated notification (#888).
public enum DisplaySpacesSetting {
    #if DEBUG
        /// Pins the mode for tests: the real read is the host's
        /// own System Settings choice, which a fixture must
        /// never inherit (the #523 rule, one preference over).
        public static nonisolated(unsafe) var hasSeparateSpacesOverride: Bool?
    #endif

    /// True when displays have separate Spaces (or the default is
    /// in effect). False only when the user explicitly turned the
    /// setting off (`spans-displays = 1`).
    public static func hasSeparateSpaces() -> Bool {
        #if DEBUG
            if let override = hasSeparateSpacesOverride {
                return override
            }
        #endif
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

    // `recommendsSharedSpaces` and `openSystemSettings` retired
    // with #888: nothing recommends the shared model any more —
    // Desktop→profile bindings key to the main display's Desktop,
    // so they are well-defined with the option on. The raw read
    // above stays: the switch handler uses it to tell a secondary
    // display's Desktop switch from a repeated notification
    // (`KiwiCore.handleNativeSpaceChange`).
}
