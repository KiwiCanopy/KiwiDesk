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
        }
    }
}
