import Foundation

/// Why the AUTOMATIC verdict floats a window (#1810) — the reason
/// a Tile refuses. The bar menu's greyed row and the refusal pill
/// both read this one value, so they cannot disagree.
public enum AutoFloatReason: Sendable, Equatable {
    /// A float rule matches the window.
    case rule
    /// A dialog, sheet, panel or raised-layer window — or one of
    /// KiwiDesk's own chrome windows.
    case panel
    /// The app runs with no Dock icon (accessory policy).
    case accessoryApp
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
