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
}

extension KiwiShelf {
    /// Whether `hex` is a colour at all: parseable and above zero
    /// alpha (#2569 ▸ "No Colour"). An empty, unparseable or fully
    /// transparent Fill is one state — no colour.
    public static func hasColour(_ hex: String) -> Bool {
        (DragVisual.parseHex(hex)?.alpha ?? 0) > 0
    }

    /// Whether the Fill has a colour.
    public var hasFill: Bool { Self.hasColour(fillColor) }

    /// The look's inks for KiwiHub and the cue plates; under
    /// Increase Contrast the dim level takes the secondary ink,
    /// since the idle ink has no legibility step of its own.
    public func panelInk(increaseContrast: Bool) -> PanelInk {
        PanelInk(
            primary: itemColor,
            secondary: peekHeaderColor,
            tertiary: increaseContrast ? peekHeaderColor : idleItemColor
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
