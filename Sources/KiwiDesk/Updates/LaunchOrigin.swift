import AppKit

/// Who started this launch (#1542: "What's new" opens only on a
/// launch the user started). Read from the open-application Apple
/// event, which is current at the top of
/// `applicationDidFinishLaunching` and not yet in
/// `applicationWillFinishLaunching` (measured, 2026-09-24).
enum LaunchOrigin: Equatable {
    case user
    case login
    /// No open event to read: treated as not the user's, so the
    /// safe answer is the mark rather than a window.
    case unknown

    static func of(_ event: NSAppleEventDescriptor?) -> LaunchOrigin {
        guard let event, event.eventID == kAEOpenApplication else {
            return .unknown
        }
        let property = event.paramDescriptor(forKeyword: keyAEPropData)
        return property?.enumCodeValue == keyAELaunchedAsLogInItem
            ? .login : .user
    }
}
