import AppKit

/// Whether this launch was the user's or the login items' (#1542:
/// "What's new" opens only on a launch the user started).
enum LaunchOrigin {
    /// Read from the Apple event that opened the app, which the
    /// login-item launch marks `keyAELaunchedAsLogInItem`. Valid
    /// only while that event is current — during launch.
    @MainActor
    static func isLoginLaunch(
        _ event: NSAppleEventDescriptor? = NSAppleEventManager.shared()
            .currentAppleEvent
    ) -> Bool {
        guard let event, event.eventID == kAEOpenApplication else {
            return false
        }
        return event.paramDescriptor(forKeyword: keyAEPropData)?
            .enumCodeValue == keyAELaunchedAsLogInItem
    }
}
