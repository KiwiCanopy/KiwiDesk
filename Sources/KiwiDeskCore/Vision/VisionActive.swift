import Foundation

/// What KiwiVision draws now (#2103 v3): off, plain KiwiVision
/// around the focused window, or a lens by its stored name — one
/// value, so "a lens is on" and "the mode is on" cannot disagree.
/// A session value no snapshot carries.
public enum VisionActive: Equatable, Sendable {
    case off
    case plain
    case lens(String)

    public var isOn: Bool { self != .off }

    /// The lens drawn, nil off or plain.
    public var lensName: String? {
        if case .lens(let name) = self { return name }
        return nil
    }
}
