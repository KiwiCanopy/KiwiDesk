import KiwiDeskCore

/// The glyph a gesture family's pin wears in a gesture row's action
/// pop-up (#3281, ui-designer and owner): the Shortcuts side's fold
/// glyph where one names the set, else one picked here for the
/// family, beside the panel's glyphs rather than in the card.
extension ShortcutsReferenceBuilder {
    static func familyIcon(for family: GestureFamily) -> String {
        switch family {
        case .focus:
            foldIcon(for: .focusDirections) ?? "arrow.left.arrow.right"
        case .swap: foldIcon(for: .swapDirections) ?? "arrow.triangle.swap"
        case .space: spaceGroupIcon
        case .display: "display.2"
        case .track: "arrow.forward.to.line"
        case .walk: CustomGlyph.walk.name
        case .layout: layoutCycle.drawn
        }
    }

    /// A modifier drag's symbol: the move's four-way arrows, the
    /// resize's diagonal (#3380), shared with its pop-up pin.
    static func grabIcon(_ grab: ModifierDragAction) -> String {
        grab == .move
            ? "arrow.up.and.down.and.arrow.left.and.right"
            : "arrow.up.left.and.arrow.down.right"
    }
}
