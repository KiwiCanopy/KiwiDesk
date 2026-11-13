import KiwiDeskCore

/// The glyph a gesture family's pin wears in a gesture row's action
/// pop-up (#3281): the Shortcuts side's own glyph for the set it
/// steps through, so the card owns no symbol table. A family covers
/// both ways, so none wears a one-sided line arrow (#2529).
extension ShortcutsReferenceBuilder {
    static func familyIcon(for family: GestureFamily) -> String {
        switch family {
        case .focus:
            foldIcon(for: .focusDirections) ?? "arrow.left.arrow.right"
        case .swap: foldIcon(for: .swapDirections) ?? "dpad.fill"
        case .space: spaceGroupIcon
        case .display: "display.2"
        case .track: "arrow.forward.to.line"
        case .walk: CustomGlyph.walk.name
        }
    }
}
