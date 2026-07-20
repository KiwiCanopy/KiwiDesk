import CoreGraphics

/// Shared active-accent metrics for both bars' item views and
/// their Settings preview twins (the GUI target reads them too).
/// Hoisted because these literals were hand-mirrored across five
/// sites and no parity test can see a drifted constant (§5) —
/// the field-list nets only catch missing properties.
public enum BarAccent {
    /// Inset of the plain/material capsule ring around the
    /// active item (ui-designer 2026-07-14): the ring floats
    /// just inside the slot so its fully-curved ends tuck
    /// inside the shared plate's rounded corners.
    public static let capsuleInset: CGFloat = 1.5

    /// Alpha for untinted content (native app images, emoji
    /// identifiers) on an inactive item. Untinted content takes
    /// no state color, so shape plus this dim carry the state.
    /// 0.4 (was 0.5): a clearer "not active" read (owner 2026-07-20).
    public static let untintedAlpha: CGFloat = 0.4

    /// The Space Bar's MIDDLE tier: an unfocused app's untinted
    /// glyph on the ACTIVE space. 0.6 (was 0.7) sits between the
    /// 1.0 focused and 0.4 inactive tiers, a firmer step than 0.7
    /// so the ladder reads clearly (owner 2026-07-20). The App Bar
    /// stays at `untintedAlpha`: its dim is a binary signal
    /// reinforced by the accent ring, no third tier to collide
    /// with — semantic parity over literal-value parity.
    public static let activeUnfocusedAlpha: CGFloat = 0.6
}
