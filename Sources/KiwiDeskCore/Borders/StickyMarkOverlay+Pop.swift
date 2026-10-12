import AppKit

/// The room the sticky mark pill's entrance pop needs (#421,
/// #2033's clip class): the plate scales past its resting size,
/// so its panel is grown around it through `PopRoom`. The pop
/// itself starts in `StickyMarkOverlay`, under its own gate.
extension StickyMarkOverlay {
    /// The pill's entrance pop. Its PEAK sizes the panel's room
    /// around the plate (`PopRoom`), so the pop is never clipped
    /// at the panel's edge — mid-expand included, since `setPill`
    /// sets the room for the whole resize (#2033's class).
    nonisolated static let popKeyframes: [(scale: CGFloat, time: Double)] =
        [(1.0, 0), (1.045, 0.45), (1.0, 1.0)]

    /// The panel around a mark resting at `mark`, room for the
    /// pop's peak on every side.
    nonisolated static func panelFrame(for mark: CGRect) -> CGRect {
        PopRoom.panelFrame(for: mark, scales: popKeyframes.map(\.scale))
    }
}
