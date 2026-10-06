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

    /// Whether an item's outline hugs its bounds: on any box,
    /// solid or glass, where the outline IS the box's edge; an
    /// item on the plate insets `capsuleInset` (QA 2026-07-19,
    /// #1924). The outline and the Space item's drop ring ask it.
    public static func hugsBox(_ shelf: KiwiShelf) -> Bool {
        !shelf.drawsPlate
    }

    /// The outline's frame and corner radius in an item's
    /// `bounds` rounded at `radius`, per `hugsBox` — both bars'
    /// items' and the front chip's. The Space item's drop ring
    /// draws its own path, morphing into this one.
    public static func outline(
        in bounds: CGRect,
        radius: CGFloat,
        shelf: KiwiShelf
    ) -> (frame: CGRect, radius: CGFloat) {
        let inset = hugsBox(shelf) ? 0 : capsuleInset
        return (
            bounds.insetBy(dx: inset, dy: inset),
            max(0, radius - inset)
        )
    }

    /// The edge mark's frame on an item's window-facing side, in
    /// its flipped `bounds` — a Space item's and the front chip's.
    public static func edgeMarkFrame(
        in bounds: CGRect,
        edge: AppBarEdge,
        thickness mark: CGFloat
    ) -> CGRect {
        switch edge {
        case .top:
            return CGRect(
                x: 0,
                y: bounds.height - mark,
                width: bounds.width,
                height: mark
            )
        case .bottom:
            return CGRect(x: 0, y: 0, width: bounds.width, height: mark)
        case .left:
            return CGRect(
                x: bounds.width - mark,
                y: 0,
                width: mark,
                height: bounds.height
            )
        case .right:
            return CGRect(x: 0, y: 0, width: mark, height: bounds.height)
        }
    }
}
