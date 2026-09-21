import CoreGraphics

/// A Space Bar item's identifier — a Space's or a layer's (#1169):
/// an SF Symbol, or text — tinted like the state (digits, a name's
/// cut, a plain character) or untinted (an emoji takes no template
/// tint). Public so the Bars preview draws Core's verdict rather
/// than a reading of its own (#1538, #702).
public enum SpaceGlyph: Equatable {
    case symbol(String)
    case text(String, tinted: Bool)
}

/// What a Space Bar identifier is painted with: `hex` the tint,
/// nil for a glyph that keeps its own colours (an emoji), and the
/// alpha it draws at.
public struct SpaceGlyphInk: Equatable {
    public var hex: String?
    public var alpha: CGFloat
}

/// An item's interaction state as the ink ladder sees it. The
/// layer item is `.active` by ruling — it exists to be noticed
/// (#1169).
public enum SpaceItemState: Equatable {
    case resting, hovered, active
}

extension SpaceBarStyle {
    /// The item colour a state takes — the one state→colour map
    /// the ink ladder and the item view's app glyphs share.
    public func itemColor(for state: SpaceItemState) -> String {
        switch state {
        case .active: return activeItemColor
        case .hovered: return hoverItemColor
        case .resting: return itemColor
        }
    }

    /// The ONE ink rule for a Space item's identifier (#1485,
    /// #702): a tinted glyph takes the state's item colour at
    /// full strength; an untinted one keeps its colours and is
    /// dimmed at rest, since the tint is the only other channel
    /// that could recede. `SpaceBarItemView` draws it and the
    /// icon picker's plate preview reads it; that both route
    /// here is `IconPickerBarPlateTests`' seam clause.
    public func identifierInk(
        of glyph: SpaceGlyph,
        state: SpaceItemState
    ) -> SpaceGlyphInk {
        let tint = itemColor(for: state)
        switch glyph {
        case .symbol, .text(_, tinted: true):
            return SpaceGlyphInk(hex: tint, alpha: 1)
        case .text(_, tinted: false):
            return SpaceGlyphInk(
                hex: nil,
                alpha: state == .resting ? dimFactor : 1
            )
        }
    }
}
