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
    ///
    /// `infinity` (#429, ui-designer): "always / everywhere" for a
    /// GLOBAL-sticky window present on every space of every
    /// monitor, and a single clean stroke that stays crisp at the
    /// 7–9 pt badge size where the old `square.stack.3d.up.fill`'s
    /// perspective smeared.
    public static let symbolName = "infinity"

    /// The DISPLAY-sticky mark (#445): `pin.fill` — "tacked to
    /// this screen" for a window present on every space of ONE
    /// monitor. A filled glyph, so it tints from `color` exactly
    /// like `infinity`. Deliberately the pin: `SpaceAssignmentChip`
    /// uses the same pin for "bound to one space", the neighbouring
    /// idea — display-sticky is "bound to one display", so the
    /// shared family reads as intended, not as a collision.
    public static let displaySymbolName = "pin.fill"

    /// The mark glyph for a scope, or nil for `.none` (no mark).
    /// One lookup so the on-window chip and the Space Bar badge
    /// pick the same per-scope glyph.
    public static func symbolName(for scope: StickyScope) -> String? {
        switch scope {
        case .none: return nil
        case .global: return symbolName
        case .display: return displaySymbolName
        }
    }

    /// On-window sticky glyph, on by default: a sticky window
    /// can look identical to a normal one, and unlike a focus
    /// border there is no native cue to fall back on.
    public var indicator = true

    /// The sticky mark's tint (#429). One value the on-window
    /// chip glyph AND the Space Bar sticky badge both read (the
    /// "one glyph everywhere" family extends to color), so the
    /// two surfaces can never drift to different colors. Empty =
    /// "Automatic": the adaptive `.labelColor` that flips with
    /// light/dark, resolved via `NSColor.mark(hex:fallback:)` —
    /// there is no fixed hex for it, so it stays the empty
    /// sentinel rather than a frozen neutral.
    public var color = ""

    public init() {}
}

// MARK: - Codable

extension StickyStyle: Codable {
    /// JSON keys are the Lua setters (`sticky.set_*`) minus the
    /// `set_` verb — the `sticky` nesting carries the namespace.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case indicator
        case color
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
        color =
            try container.decodeIfPresent(
                String.self,
                forKey: .color
            ) ?? defaults.color
    }
}
