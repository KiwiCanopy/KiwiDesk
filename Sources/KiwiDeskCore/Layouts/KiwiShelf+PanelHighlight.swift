import AppKit

/// KiwiHub's selection and hover under "Tint KiwiHub and plates"
/// (#2569 ▸ Ruling): KiwiShelf's highlight fills the selected row,
/// its hover fill the hovered one, as hex the GUI draws.
public struct PanelHighlight: Sendable, Equatable {
    public let selection: String
    /// White or black, whichever `contrastingGlyph` picks on it.
    public let selectionInk: String
    public let hover: String
    public let hoverInk: String
}

/// The inks KiwiHub and the cue plates draw on the Fill under the
/// toggle (#2569 ▸ Ruling): the look's Item colour, the dimmed step
/// the hover peek's header takes, and the idle ink — never the
/// system labels, which stay for the toggle off.
public struct PanelInk: Sendable, Equatable {
    public let primary: String
    public let secondary: String
    public let tertiary: String
    /// A divider's hairline: `tertiary` thinned (#2596).
    public let divider: String
}

extension KiwiShelf {
    /// The share of the dim panel ink a divider draws at (#2596,
    /// ui-designer): about Apple's separator, label ink at ~0.2.
    /// The far end of the panel Fill holds the dim ink at exactly
    /// `readingInkFloor` over white, so a retune of that floor moves
    /// the divider's contrast with it (`PanelDividerContrastTests`).
    public static let panelDividerAlpha: CGFloat = 0.35
    /// The divider's share under Increase Contrast.
    public static let panelDividerIncreasedAlpha: CGFloat = 0.6

    /// The look's inks for KiwiHub and the cue plates; under
    /// Increase Contrast the dim level takes the secondary ink,
    /// since the idle ink has no legibility step of its own.
    public func panelInk(increaseContrast: Bool) -> PanelInk {
        let tertiary = increaseContrast ? peekHeaderColor : idleItemColor
        let share =
            increaseContrast
            ? Self.panelDividerIncreasedAlpha : Self.panelDividerAlpha
        return PanelInk(
            primary: itemColor,
            secondary: peekHeaderColor,
            tertiary: tertiary,
            divider: Self.hex(tertiary, atShare: share)
        )
    }

    /// The selection and hover colours KiwiHub takes from the shelf.
    public var panelHighlight: PanelHighlight {
        let light = NSColor(kiwiHex: highlightColor).contrastingGlyph == .white
        return PanelHighlight(
            selection: highlightColor,
            selectionInk: light ? "#FFFFFF" : "#000000",
            hover: hoverFillColor,
            hoverInk: hoverItemColor
        )
    }
}
