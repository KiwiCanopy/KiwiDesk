import Foundation

/// The sticky-window indicator settings (#414), stored
/// top-level as `sticky` in profile JSON and set from Lua via
/// `sticky.set_*`. One knob so far: the on-window glyph that
/// marks a sticky window (`Borders/StickyIndicatorManager`), a
/// sibling of the focus border — borders are optional and often
/// off, so the mark must not ride them.
///
/// The setter applies unconditionally: turning the glyph off
/// with the Space Bar also off is a valid deliberate
/// zero-indicator state from Lua (the `dim_factor` precedent).
/// The GUI's forced-ON coverage guard is presentation only,
/// never a clamp here.
public struct StickyStyle: Sendable, Equatable {
    /// The sticky mark — ONE glyph everywhere (#414): the
    /// on-window chip and the Space Bar badge both read this,
    /// so the two surfaces can never drift apart. Lives here
    /// (the sticky namespace), not in a Bar view, so neither
    /// subsystem reaches laterally into the other for it.
    public static let symbolName = "square.stack.3d.up.fill"

    /// On-window sticky glyph, on by default: a sticky window
    /// can look identical to a normal one, and unlike a focus
    /// border there is no native cue to fall back on.
    public var indicator = true

    public init() {}
}

// MARK: - Codable

extension StickyStyle: Codable {
    /// JSON keys are the Lua setters (`sticky.set_*`) minus the
    /// `set_` verb — the `sticky` nesting carries the namespace.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case indicator
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        indicator =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .indicator
            ) ?? defaults.indicator
    }
}
