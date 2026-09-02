import Foundation

/// Desktop switch settle window duration constant
/// (`KiwiCore+SpaceCommands`, #40).
public enum DesktopSwitch {
    public static let settle: TimeInterval = 1
}

/// What the compositor says about a window that just left the AX
/// list (#1146) — the fact `WindowGoneReason.classify` decides
/// from, in place of the #40 timer that read the PREVIOUS switch
/// for a fast app's departure (#1207's trace).
public enum GonePresence: Sendable, Equatable {
    /// No compositor answer (no SkyLight): the timer decides.
    case unknown(sinceDesktopSwitch: TimeInterval)
    /// The WindowServer hosts the window on no Space.
    case gone
    /// Hosted on `space`; `shown` when some display shows it.
    case hosted(space: SkyLight.SpaceID, shown: Bool)
}

/// Reason classification for window departure from visible set (#40, #913).
public enum WindowGoneReason: String, Sendable {
    case closed
    case minimized
    case vanished
    /// Window application hid explicitly (⌘H, #913).
    case hidden

    /// Minimized wins; a window hosted on a user Desktop nobody
    /// shows is one gesture away (`vanished`); hosted nowhere,
    /// or on a Desktop the user is looking at while its app no
    /// longer lists it, it is `closed`. Without a compositor
    /// answer the settle timer decides, as before #1146.
    public static func classify(
        wasMinimized: Bool,
        presence: GonePresence
    ) -> WindowGoneReason {
        if wasMinimized { return .minimized }
        switch presence {
        case .unknown(let sinceDesktopSwitch):
            return sinceDesktopSwitch <= DesktopSwitch.settle
                ? .vanished : .closed
        case .gone:
            return .closed
        case .hosted(_, let shown):
            return shown ? .closed : .vanished
        }
    }
}

/// Reason classification for window entrance into visible set (#40).
public enum WindowAppearReason: String, Sendable {
    case new
    case returned
    case restored

    public static func classify(
        wasMinimized: Bool,
        hadRememberedSpace: Bool
    ) -> WindowAppearReason {
        if wasMinimized { return .restored }
        return hadRememberedSpace ? .returned : .new
    }
}
