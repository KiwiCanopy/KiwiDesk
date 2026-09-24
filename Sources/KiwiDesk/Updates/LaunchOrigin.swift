import AppKit
import KiwiDeskCore

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

    /// The service agent starts the binary directly, which still
    /// delivers an open event without the login-item mark — so its
    /// own environment marker is read first. An agent plist
    /// written before this marker existed reads as the user's
    /// until the service is reinstalled.
    static func of(
        _ event: NSAppleEventDescriptor?,
        environment: [String: String] = ProcessInfo.processInfo
            .environment
    ) -> LaunchOrigin {
        let marker = ServiceManager.launchMarker
        if environment[marker.key] == marker.value { return .login }
        guard let event, event.eventID == kAEOpenApplication else {
            return .unknown
        }
        let property = event.paramDescriptor(forKeyword: keyAEPropData)
        return property?.enumCodeValue == keyAELaunchedAsLogInItem
            ? .login : .user
    }
}
