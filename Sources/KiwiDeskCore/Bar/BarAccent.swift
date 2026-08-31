import CoreGraphics

/// Shared active accent metrics and alpha tiers for bar item views.
public enum BarAccent {
    /// Inset of active capsule ring inside item slot.
    public static let capsuleInset: CGFloat = 1.5

    /// Alpha for untinted content on inactive items.
    public static let untintedAlpha: CGFloat = 0.4

    /// Alpha for unfocused app glyphs on active space in Space Bar.
    public static let activeUnfocusedAlpha: CGFloat = 0.6
}
