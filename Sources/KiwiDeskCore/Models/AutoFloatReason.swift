import Foundation

/// Why the AUTOMATIC verdict floats a window (#1810) — the reason
/// a Tile refuses. The bar menu's greyed row and the refusal pill
/// both read this one value, so they cannot disagree.
public enum AutoFloatReason: Sendable, Equatable {
    /// A float rule matches the window.
    case rule
    /// A dialog, sheet or panel by its subrole — or one of
    /// KiwiDesk's own chrome windows.
    case panel
    /// A standard window on a raised CGWindow layer: judged at
    /// adoption, so a recheck never floats a tiled window on it
    /// alone (#2572).
    case raisedLayer
    /// The app runs with no Dock icon (accessory policy).
    case accessoryApp
    /// A standard window that cannot be resized — its zoom button
    /// is disabled: Settings and About windows (#2070).
    case fixedSize
    /// The window is in the pocket (#2446), which always floats
    /// it — a state, not a detection.
    case pocket

    /// Whether the reason is a GUESS a Tile rule or the switch can
    /// escape (#2173), rather than structure or the user's rule.
    public var isGuess: Bool {
        switch self {
        case .accessoryApp, .fixedSize: true
        case .rule, .panel, .raisedLayer, .pocket: false
        }
    }
}

/// Float detection's last verdict for one tracked window (#1810).
public enum FloatVerdict: Sendable, Equatable {
    case tiles
    case floats(AutoFloatReason)

    public init(_ reason: AutoFloatReason?) {
        self = reason.map { .floats($0) } ?? .tiles
    }

    public var floats: Bool { reason != nil }

    public var reason: AutoFloatReason? {
        if case .floats(let reason) = self { return reason }
        return nil
    }
}
