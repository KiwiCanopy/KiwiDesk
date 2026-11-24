import CoreGraphics

/// What the drag markers draw with (#3583): every window outline's
/// corners (#1742), the focus border colour the drop zone borrows,
/// the shelf whose Fill the ghost's plate wears, and the stored
/// `drag.liquid_glass` leaf, which the gate resolves at each draw
/// (#1374). Handed whole to `DragOverlay`, so every marker call site
/// draws the same look.
public struct DragMarkerLook: Sendable, Equatable {
    /// Corner radius in points: 0 for square corners.
    public var cornerRadius: CGFloat
    /// The look's focus border colour, `#RRGGBB` or `#RRGGBBAA`.
    public var focusColor: String
    /// The shelf, for the Fill and "Tint KiwiHub and plates".
    public var shelf: KiwiShelf
    /// The stored glass leaf, before the gate.
    public var storedGlass: Bool

    public init(
        cornerRadius: CGFloat,
        focusColor: String,
        shelf: KiwiShelf,
        storedGlass: Bool
    ) {
        self.cornerRadius = cornerRadius
        self.focusColor = focusColor
        self.shelf = shelf
        self.storedGlass = storedGlass
    }
}

extension TilingSettings {
    /// The drag markers' look as these settings state it.
    public var dragMarkerLook: DragMarkerLook {
        DragMarkerLook(
            cornerRadius: windowStroke.cornerRadius,
            focusColor: borderStyle.focusedColor,
            shelf: kiwishelf,
            storedGlass: dragLiquidGlass
        )
    }
}
