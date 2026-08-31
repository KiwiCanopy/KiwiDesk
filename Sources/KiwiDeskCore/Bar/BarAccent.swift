import CoreGraphics

/// Shared active accent metrics and alpha tiers for bar item
/// views, hoisted because the literals were hand-mirrored across
/// five sites and no parity test can see a drifted constant (§5).
public enum BarAccent {
    /// Inset of active capsule ring inside item slot.
    public static let capsuleInset: CGFloat = 1.5

    /// Alpha for untinted content on inactive items — shape plus
    /// this dim carry the state. 0.4 (was 0.5) for a clearer
    /// "not active" read (owner 2026-07-20).
    public static let untintedAlpha: CGFloat = 0.4

    /// Space Bar MIDDLE tier: 0.6 steps clearly between the 1.0
    /// focused and 0.4 inactive tiers. The App Bar keeps
    /// `untintedAlpha` — its dim is binary; semantic parity over
    /// literal-value parity (owner 2026-07-20).
    public static let activeUnfocusedAlpha: CGFloat = 0.6
}
