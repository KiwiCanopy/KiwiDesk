import Foundation

/// Desktop switch settle window duration constant
/// (`KiwiCore+SpaceCommands`, #40).
public enum DesktopSwitch {
    public static let settle: TimeInterval = 1
}

/// Reason classification for window departure from visible set (#40, #913).
public enum WindowGoneReason: String, Sendable {
    case closed
    case minimized
    case vanished
    /// Window application hid explicitly (⌘H, #913).
    case hidden

    /// Classifies window disappearance based on minimize flag and desktop
    /// switch timing.
    public static func classify(
        wasMinimized: Bool,
        sinceDesktopSwitch: TimeInterval
    ) -> WindowGoneReason {
        if wasMinimized { return .minimized }
        return sinceDesktopSwitch <= DesktopSwitch.settle
            ? .vanished : .closed
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
