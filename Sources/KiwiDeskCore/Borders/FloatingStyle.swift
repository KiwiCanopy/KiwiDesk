import Foundation

/// The floating-window mark settings (#429): sticky's sibling.
/// Sticky owns a `StickyStyle` because it has an on-window chip
/// and a toggle; floating has neither — its only visual is the
/// Space Bar floating badge — so this namespace carries just the
/// one knob today. It still earns its own `floating` group rather
/// than borrowing sticky's or the bar's: the two state colors are
/// a pair, each in its own state's namespace, and a future
/// on-window floating chip would find its color already at home
/// here (one vocabulary, AGENTS.md §5).
///
/// Set from Lua via `floating.set_*`; the setter applies
/// unconditionally (Lua is open — the `dim_factor` precedent).
public struct FloatingStyle: Sendable, Equatable {
    /// The floating mark's tint (#429): the Space Bar floating
    /// badge glyph reads it. Empty = "Automatic": the adaptive
    /// `.labelColor`, resolved via `NSColor.mark(hex:fallback:)` —
    /// the same empty-sentinel convention as `StickyStyle.color`.
    public var color = ""

    public init() {}
}

// MARK: - Codable

extension FloatingStyle: Codable {
    /// JSON keys are the Lua setters (`floating.set_*`) minus the
    /// `set_` verb — the `floating` nesting carries the namespace.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case color
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        color =
            try container.decodeIfPresent(
                String.self,
                forKey: .color
            ) ?? defaults.color
    }
}
