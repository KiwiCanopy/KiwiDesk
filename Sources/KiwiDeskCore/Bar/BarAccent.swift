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
    /// no state color, so shape plus this dim carry the state —
    /// half strength reads clearly secondary yet identifiable.
    public static let untintedAlpha: CGFloat = 0.5
}
